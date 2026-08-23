/**************************************************************************
*   Copyright (C) 2012 by Andreas Fritiofson                              *
*   andreas.fritiofson@gmail.com                                          *
*                                                                         *
*   This program is free software; you can redistribute it and/or modify  *
*   it under the terms of the GNU General Public License as published by  *
*   the Free Software Foundation; either version 2 of the License, or     *
*   (at your option) any later version.                                   *
*                                                                         *
*   This program is distributed in the hope that it will be useful,       *
*   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
*   GNU General Public License for more details.                          *
*                                                                         *
*   You should have received a copy of the GNU General Public License     *
*   along with this program.  If not, see <http://www.gnu.org/licenses/>. *
***************************************************************************/


#ifdef HAVE_CONFIG_H
#include "config.h"
#endif
/* project specific includes */
#include <jtag/drivers/jtag_usb_common.h>
#include <jtag/interface.h>
#include <jtag/swd.h>
#include <transport/transport.h>
#include <helper/time_support.h>
#include <helper/log.h>
#include <assert.h>
#include <stdio.h>
/* FTDI access library includes */
#include "mpsse.h"
#include "bitbang.h"

#define JTAG_MODE (LSB_FIRST | POS_EDGE_IN | NEG_EDGE_OUT)
#define JTAG_MODE_ALT (LSB_FIRST | NEG_EDGE_IN | NEG_EDGE_OUT)
#define SWD_MODE (LSB_FIRST | POS_EDGE_IN | NEG_EDGE_OUT)

#define DEVICE_SELECT_FPGA 0
#define DEVICE_SELECT_SOFTCORE 1


static char *device_desc;
static char *serial;
static uint8_t channel;
static uint16_t vid =  0;
static uint16_t pid =  0 ;
static uint8_t fpga_jtag_mode = JTAG_MODE;

static struct mpsse_ctx *mpsse_ctx;
struct jtag_tap *tap;



static int freq;
bool selected_device = 0;
bool fpga_initialized = 0;
static uint16_t output;
static uint16_t direction;
static uint16_t jtag_output_init;
static uint16_t jtag_direction_init;

static int fpga_tap_irlen = 6;
static int softcore_tap_irlen = 4;




/////////////////////////////////////////////////////////////////////////  State transition tracking for FPGA Chip JTAG /////////////////////

static tap_state_t chip_state_follower = TAP_RESET;

void tap_set_chip_state_impl(tap_state_t new_state)
{
	chip_state_follower = new_state;
}


void tap_set_chip_state(tap_state_t new_state)
{
	chip_state_follower = new_state;
}


tap_state_t tap_get_chip_state(void)
{
	return chip_state_follower;
}

static tap_state_t end_chip_state_follower = TAP_RESET;

void tap_set_end_chip_state(tap_state_t new_end_state)
{
	end_chip_state_follower = new_end_state;
}

tap_state_t tap_get_end_chip_state(void)
{
	return end_chip_state_follower;
}

////////////////////////////////////////////////////////////////////////  FPGA TAP Functions ////////////////////////////////////////////////////////

static void move_to_state(tap_state_t goal_state)
{
	tap_state_t start_state = tap_get_chip_state();

	/*	goal_state is 1/2 of a tuple/pair of states which allow convenient
		lookup of the required TMS pattern to move to this state from the
		start state.
	*/

	/* do the 2 lookups */
	uint8_t tms_bits  = tap_get_tms_path(start_state, goal_state);
	int tms_count = tap_get_tms_path_len(start_state, goal_state);
	assert(tms_count <= 8);

	LOG_DEBUG_IO("start=%s goal=%s", tap_state_name(start_state), tap_state_name(goal_state));

	/* Track state transitions step by step */
	for (int i = 0; i < tms_count; i++)
		tap_set_chip_state(tap_state_transition(tap_get_chip_state(), (tms_bits >> i) & 1));
		

	mpsse_clock_tms_cs_out(mpsse_ctx,
		&tms_bits,
		0,
		tms_count,
		false,
		fpga_jtag_mode);
}



static void fpga_end_state(tap_state_t state)
{
	if (tap_is_state_stable(state))
		tap_set_end_chip_state(state);
	else {
		LOG_ERROR("BUG: %s is not a stable end state", tap_state_name(state));
		exit(-1);
	}
}

static void fpga_execute_runtest(struct jtag_command *cmd)
{
	int i;
	uint8_t zero = 0;

	LOG_DEBUG_IO("runtest %i cycles, end in %s",
		cmd->cmd.runtest->num_cycles,
		tap_state_name(cmd->cmd.runtest->end_state));

	if (tap_get_chip_state() != TAP_IDLE)
		move_to_state(TAP_IDLE);

	/* TODO: Reuse ftdi_execute_stableclocks */
	i = cmd->cmd.runtest->num_cycles;
	while (i > 0) {
		/* there are no state transitions in this code, so omit state tracking */
		unsigned this_len = i > 7 ? 7 : i;
		mpsse_clock_tms_cs_out(mpsse_ctx, &zero, 0, this_len, false, fpga_jtag_mode);
		i -= this_len;
	}

	fpga_end_state(cmd->cmd.runtest->end_state);

	if (tap_get_chip_state() != tap_get_end_chip_state())
		move_to_state(tap_get_end_chip_state());

	LOG_DEBUG_IO("runtest: %i, end in %s",
		cmd->cmd.runtest->num_cycles,
		tap_state_name(tap_get_end_chip_state()));
}

static void fpga_execute_statemove(struct jtag_command *cmd)
{
	LOG_DEBUG_IO("statemove end in %s",
		tap_state_name(cmd->cmd.statemove->end_state));

	fpga_end_state(cmd->cmd.statemove->end_state);

	/* shortest-path move to desired end state */
	if (tap_get_chip_state() != tap_get_end_chip_state() || tap_get_end_chip_state() == TAP_RESET)
		move_to_state(tap_get_end_chip_state());
}

/**
 * Clock a bunch of TMS (or SWDIO) transitions, to change the JTAG
 * (or SWD) state machine. REVISIT: Not the best method, perhaps.
 */
static void fpga_execute_tms(struct jtag_command *cmd)
{
	LOG_DEBUG_IO("TMS: %d bits", cmd->cmd.tms->num_bits);

	/* TODO: Missing tap state tracking, also missing from ft2232.c! */
	mpsse_clock_tms_cs_out(mpsse_ctx,
		cmd->cmd.tms->bits,
		0,
		cmd->cmd.tms->num_bits,
		false,
		fpga_jtag_mode);
}

static void fpga_execute_pathmove(struct jtag_command *cmd)
{
	tap_state_t *path = cmd->cmd.pathmove->path;
	int num_states  = cmd->cmd.pathmove->num_states;

	LOG_DEBUG_IO("pathmove: %i states, current: %s  end: %s", num_states,
		tap_state_name(tap_get_chip_state()),
		tap_state_name(path[num_states-1]));

	int state_count = 0;
	unsigned bit_count = 0;
	uint8_t tms_byte = 0;

	LOG_DEBUG_IO("-");

	/* this loop verifies that the path is legal and logs each state in the path */
	while (num_states--) {

		/* either TMS=0 or TMS=1 must work ... */
		if (tap_state_transition(tap_get_chip_state(), false)
		    == path[state_count])
			buf_set_u32(&tms_byte, bit_count++, 1, 0x0);
		else if (tap_state_transition(tap_get_chip_state(), true)
			 == path[state_count]) {
			buf_set_u32(&tms_byte, bit_count++, 1, 0x1);

			/* ... or else the caller goofed BADLY */
		} else {
			LOG_ERROR("BUG: %s -> %s isn't a valid "
				"TAP state transition",
				tap_state_name(tap_get_chip_state()),
				tap_state_name(path[state_count]));
			exit(-1);
		}

		tap_set_chip_state(path[state_count]);
		state_count++;

		if (bit_count == 7 || num_states == 0) {
			mpsse_clock_tms_cs_out(mpsse_ctx,
					&tms_byte,
					0,
					bit_count,
					false,
					fpga_jtag_mode);
			bit_count = 0;
		}
	}
	tap_set_end_chip_state(tap_get_chip_state());
}




static void fpga_execute_scan(struct jtag_command *cmd)
{
	LOG_DEBUG_IO("%s type:%d", cmd->cmd.scan->ir_scan ? "IRSCAN" : "DRSCAN",
		jtag_scan_type(cmd->cmd.scan));

	/* Make sure there are no trailing fields with num_bits == 0, or the logic below will fail. */
	while (cmd->cmd.scan->num_fields > 0
			&& cmd->cmd.scan->fields[cmd->cmd.scan->num_fields - 1].num_bits == 0) {
		cmd->cmd.scan->num_fields--;
		LOG_DEBUG_IO("discarding trailing empty field");
	}

	if (cmd->cmd.scan->num_fields == 0) {
		LOG_DEBUG_IO("empty scan, doing nothing");
		return;
	}

	if (cmd->cmd.scan->ir_scan) {
		if (tap_get_chip_state() != TAP_IRSHIFT)
			move_to_state(TAP_IRSHIFT);
	} else {
		if (tap_get_chip_state() != TAP_DRSHIFT)
			move_to_state(TAP_DRSHIFT);
	}

	fpga_end_state(cmd->cmd.scan->end_state);

	struct scan_field *field = cmd->cmd.scan->fields;
	unsigned scan_size = 0;

	for (int i = 0; i < cmd->cmd.scan->num_fields; i++, field++) {
		scan_size += field->num_bits;
		LOG_DEBUG_IO("%s%s field %d/%d %d bits",
			field->in_value ? "in" : "",
			field->out_value ? "out" : "",
			i,
			cmd->cmd.scan->num_fields,
			field->num_bits);

		if (i == cmd->cmd.scan->num_fields - 1 && tap_get_chip_state() != tap_get_end_chip_state()) {
			/* Last field, and we're leaving IRSHIFT/DRSHIFT. Clock last bit during tap
			 * movement. This last field can't have length zero, it was checked above. */
			mpsse_clock_data(mpsse_ctx,
				field->out_value,
				0,
				field->in_value,
				0,
				field->num_bits - 1,
				fpga_jtag_mode);
			uint8_t last_bit = 0;
			if (field->out_value)
				bit_copy(&last_bit, 0, field->out_value, field->num_bits - 1, 1);

			/* If endstate is TAP_IDLE, clock out 1-1-0 (->EXIT1 ->UPDATE ->IDLE)
			 * Otherwise, clock out 1-0 (->EXIT1 ->PAUSE)
			 */
			uint8_t tms_bits = 0x03;
			mpsse_clock_tms_cs(mpsse_ctx,
					&tms_bits,
					0,
					field->in_value,
					field->num_bits - 1,
					1,
					last_bit,
					fpga_jtag_mode);
			tap_set_chip_state(tap_state_transition(tap_get_chip_state(), 1));
			if (tap_get_end_chip_state() == TAP_IDLE) {
				mpsse_clock_tms_cs_out(mpsse_ctx,
						&tms_bits,
						1,
						2,
						last_bit,
						fpga_jtag_mode);
				tap_set_chip_state(tap_state_transition(tap_get_chip_state(), 1));
				tap_set_chip_state(tap_state_transition(tap_get_chip_state(), 0));
			} else {
				mpsse_clock_tms_cs_out(mpsse_ctx,
						&tms_bits,
						2,
						1,
						last_bit,
						fpga_jtag_mode);
				tap_set_chip_state(tap_state_transition(tap_get_chip_state(), 0));
			}
		} else
			mpsse_clock_data(mpsse_ctx,
				field->out_value,
				0,
				field->in_value,
				0,
				field->num_bits,
				fpga_jtag_mode);
	}

	if (tap_get_chip_state() != tap_get_end_chip_state())
		move_to_state(tap_get_end_chip_state());

	LOG_DEBUG_IO("%s scan, %i bits, end in %s",
		(cmd->cmd.scan->ir_scan) ? "IR" : "DR", scan_size,
		tap_state_name(tap_get_end_chip_state()));
}

static void fpga_execute_stableclocks(struct jtag_command *cmd)
{
	/* this is only allowed while in a stable state.  A check for a stable
	 * state was done in jtag_add_clocks()
	 */
	int num_cycles = cmd->cmd.stableclocks->num_cycles;

	/* 7 bits of either ones or zeros. */
	uint8_t tms = tap_get_chip_state() == TAP_RESET ? 0x7f : 0x00;

	/* TODO: Use mpsse_clock_data with in=out=0 for this, if TMS can be set to
	 * the correct level and remain there during the scan */
	while (num_cycles > 0) {
		/* there are no state transitions in this code, so omit state tracking */
		unsigned this_len = num_cycles > 7 ? 7 : num_cycles;
		mpsse_clock_tms_cs_out(mpsse_ctx, &tms, 0, this_len, false, fpga_jtag_mode);
		num_cycles -= this_len;
	}

	LOG_DEBUG_IO("clocks %i while in %s",
		cmd->cmd.stableclocks->num_cycles,
		tap_state_name(tap_get_chip_state()));
}

static void fpga_execute_sleep(struct jtag_command *cmd)
{
	LOG_DEBUG_IO("sleep %" PRIu32, cmd->cmd.sleep->us);

	mpsse_flush(mpsse_ctx);
	jtag_sleep(cmd->cmd.sleep->us);
	LOG_DEBUG_IO("sleep %" PRIu32 " usec while in %s",
		cmd->cmd.sleep->us,
		tap_state_name(tap_get_chip_state()));
}



/////////////////////////////////////////////////////////////////////////////////////////////////////////// Softcore //////////////////////////////////////////////////////////////-------------------------------------------------------------------------------------------------------//////

void softcore_dr_scan(int num_bits, const uint8_t *out_bits, uint8_t *in_bits, tap_state_t state){
	struct jtag_command *cmd = cmd_queue_alloc(sizeof(struct jtag_command));
	struct scan_command *scan = cmd_queue_alloc(sizeof(struct scan_command));
	struct scan_field *out_fields = cmd_queue_alloc(sizeof(struct scan_field));

	cmd->type = JTAG_SCAN;
	cmd->cmd.scan = scan;

	scan->ir_scan = false;
	scan->num_fields = 1;
	scan->fields = out_fields;
	scan->end_state = state;

	out_fields->num_bits = num_bits;
	out_fields->out_value = buf_cpy(out_bits, cmd_queue_alloc(DIV_ROUND_UP(num_bits, 8)), num_bits);
	out_fields->in_value = in_bits;
	
	fpga_execute_scan(cmd);
	mpsse_flush(mpsse_ctx);
	return;

}

static bb_value_t softcore_read(void)
{

	uint8_t command = 8;
	uint8_t data;
        softcore_dr_scan(4,  &command, &data, TAP_IDLE);
	return (data) ? BB_HIGH : BB_LOW;
}

static int softcore_write(int tck, int tms, int tdi)
{	
	uint8_t command;
	uint8_t data;
	command =tck  |  (tms << 1) | (tdi << 2);
        softcore_dr_scan(4,  &command, &data, TAP_IDLE);	
	return ERROR_OK;
}


static struct bitbang_interface softcore_bitbang = {
	.read = softcore_read,
	.write = softcore_write
};

//////////////////////////////////////////////////////////////  Queue and command handler with emulation support ///////////////////////////////////////


static void fpga_execute_command(struct jtag_command *cmd)
{
	switch (cmd->type) {
		case JTAG_RUNTEST:
			fpga_execute_runtest(cmd);
			break;
		case JTAG_TLR_RESET:
			fpga_execute_statemove(cmd);
			break;
		case JTAG_PATHMOVE:
			fpga_execute_pathmove(cmd);
			break;
		case JTAG_SCAN:
			fpga_execute_scan(cmd);
			break;
		case JTAG_SLEEP:
			fpga_execute_sleep(cmd);
			break;
		case JTAG_STABLECLOCKS:
			fpga_execute_stableclocks(cmd);
			break;
		case JTAG_TMS:
			fpga_execute_tms(cmd);
			break;
		case JTAG_SELECT_CHIP:
			selected_device = DEVICE_SELECT_FPGA;
			tap = jtag_tap_next_enabled(NULL);
			tap -> ir_length = fpga_tap_irlen;
			break;
		case JTAG_SELECT_SOFTCORE:
			selected_device = DEVICE_SELECT_SOFTCORE;
			tap = jtag_tap_next_enabled(NULL);
			tap -> ir_length = softcore_tap_irlen;
			
			break;
		default:
			LOG_ERROR("BUG: unknown JTAG command type encountered: %d", cmd->type);
			break;
	}
}

static int emulate_execute_queue(void)
{
	int retval = ERROR_OK;
	if (selected_device ==DEVICE_SELECT_FPGA ){
		for (struct jtag_command *cmd = jtag_command_queue; cmd; cmd = cmd->next) {
				fpga_execute_command(cmd);
		}
		retval = mpsse_flush(mpsse_ctx);
		if (retval != ERROR_OK)
			LOG_ERROR("error while flushing MPSSE queue: %d", retval);
	}
	else {
		// check if any of the commands is switching over to chip
		for (struct jtag_command *cmd = jtag_command_queue; cmd; cmd = cmd->next) {
			if (cmd->type == JTAG_SELECT_CHIP){
				selected_device = DEVICE_SELECT_FPGA;
			}
			
		}
		// if no target switch, call the bitbang execute queue
		if (selected_device == DEVICE_SELECT_SOFTCORE){
				bitbang_execute_queue();
		}	
	}
	return retval;
}


//////////////////////////////////////////////////////////////////////////  Setup adapter ///////////////////////////////////////////////////////////////////////



static int emulate_initialize(void)
{

	bitbang_interface = &softcore_bitbang;
	mpsse_ctx = mpsse_open(&vid, &pid, device_desc,
				serial, jtag_usb_get_location(), channel);

	if (!mpsse_ctx)
		return ERROR_JTAG_INIT_FAILED;

	output = jtag_output_init;
	direction = jtag_direction_init;
	mpsse_set_data_bits_low_byte(mpsse_ctx, output & 0xff, direction & 0xff);
	mpsse_set_data_bits_high_byte(mpsse_ctx, output >> 8, direction >> 8);
	mpsse_loopback_config(mpsse_ctx, false);
	freq = mpsse_set_frequency(mpsse_ctx, jtag_get_speed_khz() * 1000);
	return  mpsse_flush(mpsse_ctx);
}

static int emulate_reset(int trst, int srst)
{
	return mpsse_flush(mpsse_ctx);
}


static int emulate_quit(void)
{
	mpsse_close(mpsse_ctx);
	return ERROR_OK;
}


static int emulate_speed(int speed)
{
	int retval;
	retval = mpsse_set_frequency(mpsse_ctx, speed);

	if (retval < 0) {
		LOG_ERROR("couldn't set FTDI TCK speed");
		return retval;
	}

	return ERROR_OK;
}

static int emulate_speed_div(int speed, int *khz)
{
	*khz = speed / 1000;
	return ERROR_OK;
}

static int emulate_khz(int khz, int *jtag_speed)
{
	if (khz == 0 && !mpsse_is_high_speed(mpsse_ctx)) {
		LOG_DEBUG("RCLK not supported");
		return ERROR_FAIL;
	}
	*jtag_speed = khz * 1000;
	return ERROR_OK;
}


//////////////////////////////////////////////////////////////////////  Command Handlers //////////////////////////////////////////////////


COMMAND_HANDLER(emulate_handle_device_desc_command)
{
	if (CMD_ARGC == 1) {
		free(device_desc);
		device_desc = strdup(CMD_ARGV[0]);
	} else {
		LOG_ERROR("expected exactly one argument to emulate device_desc <description>");
	}

	return ERROR_OK;
}



COMMAND_HANDLER(emulate_handle_channel_command)
{
	if (CMD_ARGC == 1)
		COMMAND_PARSE_NUMBER(u8, CMD_ARGV[0], channel);
	else
		return ERROR_COMMAND_SYNTAX_ERROR;

	return ERROR_OK;
}

COMMAND_HANDLER(emulate_handle_layout_init_command)
{
	if (CMD_ARGC != 2)
		return ERROR_COMMAND_SYNTAX_ERROR;
	COMMAND_PARSE_NUMBER(u16, CMD_ARGV[0], jtag_output_init);
	COMMAND_PARSE_NUMBER(u16, CMD_ARGV[1], jtag_direction_init);
	return ERROR_OK;
}



COMMAND_HANDLER(emulate_handle_vid_pid_command)
{
	COMMAND_PARSE_NUMBER(u16, CMD_ARGV[0], vid);
	COMMAND_PARSE_NUMBER(u16, CMD_ARGV[ 1], pid);
	return ERROR_OK;
}



COMMAND_HANDLER(emulate_handle_fpga_tap_irlen_command)
{
	COMMAND_PARSE_NUMBER(int, CMD_ARGV[0], fpga_tap_irlen);
	return ERROR_OK;
}




COMMAND_HANDLER(emulate_handle_softcore_tap_irlen_command)
{
	COMMAND_PARSE_NUMBER(int, CMD_ARGV[0], softcore_tap_irlen);
	return ERROR_OK;
}





static const struct command_registration emulate_subcommand_handlers[] = {
	{
		.name = "device_desc",
		.handler = &emulate_handle_device_desc_command,
		.mode = COMMAND_CONFIG,
		.help = "set the USB device description of the FTDI device",
		.usage = "description_string",
	},
	{
		.name = "channel",
		.handler = &emulate_handle_channel_command,
		.mode = COMMAND_CONFIG,
		.help = "set the channel of the FTDI device that is used as JTAG",
		.usage = "(0-3)",
	},
	{
		.name = "layout_init",
		.handler = &emulate_handle_layout_init_command,
		.mode = COMMAND_CONFIG,
		.help = "initialize the FPGA GPIO signals used "
			"to control output-enables and reset signals",
		.usage = "data direction",
	},
	{
		.name = "vid_pid",
		.handler = &emulate_handle_vid_pid_command,
		.mode = COMMAND_CONFIG,
		.help = "the vendor ID and product ID of the FPGA",
		.usage = "(vid pid)*",
	},
	{
		.name = "fpga_tap_irlen",
		.handler = &emulate_handle_fpga_tap_irlen_command,
		.mode = COMMAND_CONFIG,
		.help = "the irlen for FPGA TAP",
		.usage = "(irlen)*",
	},
	{
		.name = "softcore_tap_irlen",
		.handler = &emulate_handle_softcore_tap_irlen_command,
		.mode = COMMAND_CONFIG,
		.help = "the irlen for Softcore TAP",
		.usage = "(irlen)*",
	},
	COMMAND_REGISTRATION_DONE
};


static const struct command_registration emulate_command_handlers[] = {
	{
		.name = "emulate",
		.mode = COMMAND_ANY,
		.help = "perform emulate management",
		.chain = emulate_subcommand_handlers,
		.usage = "",
	},
	COMMAND_REGISTRATION_DONE
};



/////////////////////////////////////////////////////////////////////////////  Adapter structs ///////////////////////////////////////////////////
static const char * const emulate_transports[] = { "jtag", NULL };

static struct jtag_interface emulate_interface = {
	.supported = DEBUG_CAP_TMS_SEQ,
	.execute_queue = emulate_execute_queue,
};

struct adapter_driver emulate_adapter_driver = {
	.name = "emulate",
	.transports = emulate_transports,
	.commands = emulate_command_handlers,

	.init = emulate_initialize,
	.quit = emulate_quit,
	.reset = emulate_reset,
	.speed = emulate_speed,
	.khz = emulate_khz,
	.speed_div = emulate_speed_div,

	.jtag_ops = &emulate_interface
};
