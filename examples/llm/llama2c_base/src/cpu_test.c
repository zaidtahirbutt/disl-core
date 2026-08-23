#include <stdarg.h> 
#include <stdint.h>
#include <stddef.h>
#include "utils.h"
#include "floate.h"
#include <string.h>
#include <stdlib.h>



#define START_SECTOR  256
#define MODEL_SIZE  60816384
#define MODEL_SECTORS MODEL_SIZE/SD_BLOCK_LEN 
#define TOKENIZER_SIZE  434176
#define TOKENIZER_SECTORS TOKENIZER_SIZE/SD_BLOCK_LEN 
uint8_t* model_data; 
uint8_t* tokenizer_data; 

// uint8_t sdread_multiple_sectors(uint8_t* model_data, uint32_t start_sector, uint32_t end_sector){
//     uint8_t res1, read, token;
//     uint32_t* buf = (uint32_t*) model_data;
//     uint16_t readAttempts;
//     // set token to none
//     token = 0xFF;
//     // assert chip select
//     SPI_transfer(0xFF);
//     // send CMD17
//     SD_command(18, start_sector, 0x00);
//     // read R1
//     uint32_t curr_sector = start_sector;
//     while(curr_sector < end_sector){
//         res1 = SD_readRes1();
//         // if response received from card
//         if(res1 != 0xFF)
//         {
//             // wait for a response token (timeout = 100ms)
//             readAttempts = 0;
//             while(++readAttempts != SD_MAX_READ_ATTEMPTS)
//                 if((read = SPI_transfer(0xFF)) != 0xFF) break;

//             // if response token is 0xFE
//             if(read == 0xFE)
//             {
//                 // read 512 byte block
//                 for(uint16_t i = 0; i < 512; i+=4){
//                     uint32_t a = SPI_transfer(0xFF);
//                     uint32_t b = SPI_transfer(0xFF);
//                     uint32_t c = SPI_transfer(0xFF);
//                     uint32_t d = SPI_transfer(0xFF);
//                     *buf++ = a | (b << 8) | (c << 16) | (d << 24);
//                 }

//                 // read 16-bit CRC
//                 SPI_transfer(0xFF);
//                 SPI_transfer(0xFF);
//                 SPI_transfer(0xFF);
//                 curr_sector++;
//             }

//             // set token to card response
//             token = read;
//         }
//     }
//     SD_command(12, 0, 0x00);
//     while (SPI_transfer(0xFF) != 0xFF);
//     SPI_transfer(0xFF);
//     return res1;
// }


void load_files(){
  uint8_t buf[SD_BLOCK_LEN];
  uint32_t timer_start, timer_stop, timer_diff;
  
  timer_start = timer;

  // sdread_multiple_sectors(model_data, START_SECTOR, MODEL_SECTORS+START_SECTOR);

  for (int i = START_SECTOR; i < MODEL_SECTORS+START_SECTOR; i++){
    while(sdread(i,buf));
    for (int j = 0; j < SD_BLOCK_LEN; j++){
      model_data[(i-START_SECTOR)*SD_BLOCK_LEN+j] = buf[j];
    }
  }

  timer_stop = timer;
  timer_diff = (timer_stop-timer_start)/1000000;
  printf("Loaded model data in %d seconds\n\r", timer_diff);
  timer_start = timer;

  for (int i = MODEL_SECTORS+START_SECTOR; i < MODEL_SECTORS+START_SECTOR+TOKENIZER_SECTORS; i++){
    while(sdread(i,buf));
    for (int j = 0; j < SD_BLOCK_LEN; j++){
      tokenizer_data[(i-(MODEL_SECTORS+START_SECTOR))*SD_BLOCK_LEN+j] = buf[j];
    }
  }

  timer_stop = timer;
  timer_diff = (timer_stop-timer_start)/1000000;
  printf("Loaded tokenizer data in %d seconds\n\r", timer_diff);
}

// loadfile(0x100);
  

int isspace(int c) {
    return (c == ' ' || c == '\f' || c == '\n' || c == '\r' || c == '\t' || c == '\v');
}

int isprint(int c) {
    return (c >= 33 && c <= 126);
}


// ----------------------------------------------------------------------------
// Transformer model

typedef struct {
    int dim; // transformer dimension
    int hidden_dim; // for ffn layers
    int n_layers; // number of layers
    int n_heads; // number of query heads
    int n_kv_heads; // number of key/value heads (can be < query heads because of multiquery)
    int vocab_size; // vocabulary size, usually 256 (byte-level)
    int seq_len; // max sequence length
} Config;

typedef struct {
    // token embedding table
    floate* token_embedding_table;    // (vocab_size, dim)
    // weights for rmsnorms
    floate* rms_att_weight; // (layer, dim) rmsnorm weights
    floate* rms_ffn_weight; // (layer, dim)
    // weights for matmuls. note dim == n_heads * head_size
    floate* wq; // (layer, dim, n_heads * head_size)
    floate* wk; // (layer, dim, n_kv_heads * head_size)
    floate* wv; // (layer, dim, n_kv_heads * head_size)
    floate* wo; // (layer, n_heads * head_size, dim)
    // weights for ffn
    floate* w1; // (layer, hidden_dim, dim)
    floate* w2; // (layer, dim, hidden_dim)
    floate* w3; // (layer, hidden_dim, dim)
    // final rmsnorm
    floate* rms_final_weight; // (dim,)
    // (optional) classifier weights for the logits, on the last layer
    floate* wcls;
} TransformerWeights;

typedef struct {
    // current wave of activations
    floate *x; // activation at current time stamp (dim,)
    floate *xb; // same, but inside a residual branch (dim,)
    floate *xb2; // an additional buffer just for convenience (dim,)
    floate *hb; // buffer for hidden dimension in the ffn (hidden_dim,)
    floate *hb2; // buffer for hidden dimension in the ffn (hidden_dim,)
    floate *q; // query (dim,)
    floate *k; // key (dim,)
    floate *v; // value (dim,)
    floate *att; // buffer for scores/attention values (n_heads, seq_len)
    floate *logits; // output logits
    // kv cache
    floate* key_cache;   // (layer, seq_len, dim)
    floate* value_cache; // (layer, seq_len, dim)
} RunState;

typedef struct {
    Config config; // the hyperparameters of the architecture (the blueprint)
    TransformerWeights weights; // the weights of the model
    RunState state; // buffers for the "wave" of activations in the forward pass
    // some more state needed to properly clean up the memory mapping (sigh)
    int fd; // file descriptor for memory mapping
    floate* data; // memory mapped data pointer
    unsigned int file_size; // size of the checkpoint file in bytes
} Transformer;

void malloc_run_state(RunState* s, Config* p) {
    // we calloc instead of malloc to keep valgrind happy
    int kv_dim = (p->dim * p->n_kv_heads) / p->n_heads;
    s->x = calloc(p->dim, sizeof(floate));
    s->xb = calloc(p->dim, sizeof(floate));
    s->xb2 = calloc(p->dim, sizeof(floate));
    s->hb = calloc(p->hidden_dim, sizeof(floate));
    s->hb2 = calloc(p->hidden_dim, sizeof(floate));
    s->q = calloc(p->dim, sizeof(floate));
    s->key_cache = calloc(p->n_layers * p->seq_len * kv_dim, sizeof(floate));
    s->value_cache = calloc(p->n_layers * p->seq_len * kv_dim, sizeof(floate));
    s->att = calloc(p->n_heads * p->seq_len, sizeof(floate));
    s->logits = calloc(p->vocab_size, sizeof(floate));
}

void free_run_state(RunState* s) {
    free(s->x);
    free(s->xb);
    free(s->xb2);
    free(s->hb);
    free(s->hb2);
    free(s->q);
    free(s->att);
    free(s->logits);
    free(s->key_cache);
    free(s->value_cache);
}

void memory_map_weights(TransformerWeights *w, Config* p, floate* ptr, int shared_weights) {
    int head_size = p->dim / p->n_heads;
    // make sure the multiplications below are done in 64bit to fit the parameter counts of 13B+ models
    unsigned int n_layers = p->n_layers;
    w->token_embedding_table = ptr;
    ptr += p->vocab_size * p->dim;
    w->rms_att_weight = ptr;
    ptr += n_layers * p->dim;
    w->wq = ptr;
    ptr += n_layers * p->dim * (p->n_heads * head_size);
    w->wk = ptr;
    ptr += n_layers * p->dim * (p->n_kv_heads * head_size);
    w->wv = ptr;
    ptr += n_layers * p->dim * (p->n_kv_heads * head_size);
    w->wo = ptr;
    ptr += n_layers * (p->n_heads * head_size) * p->dim;
    w->rms_ffn_weight = ptr;
    ptr += n_layers * p->dim;
    w->w1 = ptr;
    ptr += n_layers * p->dim * p->hidden_dim;
    w->w2 = ptr;
    ptr += n_layers * p->hidden_dim * p->dim;
    w->w3 = ptr;
    ptr += n_layers * p->dim * p->hidden_dim;
    w->rms_final_weight = ptr;
    ptr += p->dim;
    ptr += p->seq_len * head_size / 2; // skip what used to be freq_cis_real (for RoPE)
    ptr += p->seq_len * head_size / 2; // skip what used to be freq_cis_imag (for RoPE)
    w->wcls = shared_weights ? w->token_embedding_table : ptr;
}



void build_transformer(Transformer *t) {
    char *_config = (char*)(&t->config);
    int i;
    for (i = 0; i < sizeof(Config); i++)
        _config[i] = model_data[i];

    Config* cfg = (Config*) _config;
    printf("Printing config: \n\r");
    printf("dim: %d, hidden_dim: %d, n_layers: %d, n_heads: %d, n_kv_heads: %d, vocab_size: %d, seq_len: %d\n\r",cfg->dim, 
    cfg->hidden_dim, cfg->n_layers, cfg->n_heads, cfg->n_kv_heads, cfg->vocab_size, cfg->seq_len);
    int shared_weights =  (&t->config)->vocab_size > 0 ? 1 : 0;
    (&t->config)->vocab_size = abs( (&t->config)->vocab_size);
    *(&t->data) = (floate*) model_data;
    floate* weights_ptr = *(&t->data) + sizeof(Config)/sizeof(floate);
    // printf("Mapping memory weights\n\r");
    memory_map_weights(&t->weights, &t->config, weights_ptr, shared_weights);
    t->file_size = MODEL_SIZE;
    // printf("allocate the RunState buffers\n\r");
    malloc_run_state(&t->state, &t->config);
}

void free_transformer(Transformer* t) {
    // close the memory mapping
    //if (t->data != MAP_FAILED) { munmap(t->data, t->file_size); }
    // free the RunState buffers
    free_run_state(&t->state);
}

// ----------------------------------------------------------------------------
// neural net blocks; the dynamics of the Transformer

void rmsnorm(floate* o, floate* x, floate* weight, int size) {
    // calculate sum of squares
    floate ss = initfe(0,0,0);
    for (int j = 0; j < size; j++) {    
        ss = addf(ss, mulf(x[j] , x[j]));
    }
    ss = divfi(ss,size);
    ss = addf(ss, initfe(0,110,2606508));
    ss = invsqrtff(ss);
    // normalize and scale
    for (int j = 0; j < size; j++) {
        o[j] = mulf(weight[j] , mulf (ss , x[j]));
    }
}

void softmax(floate* x, int size) {
    // find max value (for numerical stability)
    floate max_val = x[0];
    for (int i = 1; i < size; i++) {
        if (gtf(x[i],max_val)) {
            max_val = x[i];
        }
    }
    // exp and sum
    floate sum = initfe(0,0,0);
    for (int i = 0; i < size; i++) {
        x[i] = expff(subf(x[i],max_val));
        sum  = addf(sum,x[i]);
    }
    // normalize
    for (int i = 0; i < size; i++) {
        x[i] = divf(x[i],sum);
    }
}

void matmul(floate* xout, floate* x, floate* w, int n, int d) {
    // W (d,n) @ x (n,) -> xout (d,)
    // by far the most amount of time is spent inside this little function
    // printf("MATMUL - W(%d,%d) * x(%d,) -> y(%d,)\n\r", d,n,n,d);
    int i;
    floate ret;
    for (i = 0; i < d; i++) {
        floate val = initfe(0,0,0);
        for (int j = 0; j < n; j+=16) {
            for (int k = 0; k < 16; k++){
                floate a = w[i * n + j + k];
                floate b = x[j + k];
                // printf("%f x %f + ",a,b);
                __asm__ (".insn r 0x2B , 0, 0x5, %[rd] , %[rs1], %[rs2]" : [rd] "=r" (ret) : [rs1] "r" (a), [rs2] "r" (b));
            } 
            __asm__ (".insn r 0x2B , 0, 0x6, %[rd] , %[rs1], %[rs2]" : [rd] "=r" (ret) : [rs1] "r" (ret), [rs2] "r" (ret));
            // printf("= %f \r\n", ret);
            val = addf(val,ret);
        }
        xout[i] = val;
    }
}

floate* forward(Transformer* transformer, int token, int pos) {
    uint32_t timer_start,timer_stop,timer_diff;
    // printf("a few convenience variables\n\r");

    timer_start = timer;

    Config* p = &transformer->config;
    TransformerWeights* w = &transformer->weights;
    RunState* s = &transformer->state;
    floate *x = s->x;
    int dim = p->dim;
    int kv_dim = (p->dim * p->n_kv_heads) / p->n_heads;
    int kv_mul = p->n_heads / p->n_kv_heads; // integer multiplier of the kv sharing in multiquery
    int hidden_dim =  p->hidden_dim;
    int head_size = dim / p->n_heads;

    // printf("copy the token embedding into x\r\n");
    floate* content_row = w->token_embedding_table + token * dim;
    memcpy(x, content_row, dim*sizeof(*x));

    // timer_stop = timer;
    // timer_diff = (timer_stop-timer_start)/1000000;
    // printf("FORWARD - Initial setup took %d seconds\n\r", timer_diff);

    // printf("FORWARD - Running through all the layers\r\n");
    for(unsigned int l = 0; l < p->n_layers; l++) {
        timer_start = timer;
        rmsnorm(s->xb, x, w->rms_att_weight + l*dim, dim);
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("FORWARD (Layer %d) - attention rmsnorm took %d seconds\r\n", l , timer_diff);

        
        timer_start = timer;
        int loff = l * p->seq_len * kv_dim; // kv cache layer offset for convenience
        s->k = s->key_cache + loff + pos * kv_dim;
        s->v = s->value_cache + loff + pos * kv_dim;
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("FORWARD (Layer %d) - key and value point to the kv cache took %d seconds\r\n", l , timer_diff);

        // printf("qkv matmuls for this position\r\n");
        timer_start = timer;
        matmul(s->q, s->xb, w->wq + l*dim*dim, dim, dim);
        matmul(s->k, s->xb, w->wk + l*dim*kv_dim, dim, kv_dim);
        matmul(s->v, s->xb, w->wv + l*dim*kv_dim, dim, kv_dim);
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("FORWARD (Layer %d) - qkv matmuls for this position took %d seconds\r\n", l , timer_diff);


        // printf("RoPE relative positional encoding: complex-valued rotate q and k in each head\r\n");
        timer_start = timer;
        for (int i = 0; i < dim; i+=2) {
            int head_dim = i % head_size;
            floate freq = divf(initfe(0, 127, 0) , powff(initfe(0, 140, 1851392), divf(itofe(head_dim) , itofe(head_size))));
            floate val = mulf(itofe(pos) , freq);
            floate fcr = cosff(val);
            floate fci = sinff(val);
            int rotn = i < kv_dim ? 2 : 1; // how many vectors? 2 = q & k, 1 = q only
            for (int v = 0; v < rotn; v++) {
                floate* vec = v == 0 ? s->q : s->k; // the vector to rotate (query or key)
                floate v0 = vec[i];
                floate v1 = vec[i+1];
                vec[i]   = subf(mulf(v0 , fcr) , mulf(v1 , fci));
                vec[i+1] = addf(mulf(v0 , fci) , mulf(v1 , fcr));
            }
        }
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("FORWARD (Layer %d) - RoPE relative positional encoding: complex-valued rotate q and k in each head took %d seconds\r\n", l , timer_diff);


        // printf("multihead attention. iterate over all heads\r\n");
        timer_start = timer;
        int h;
        for (h = 0; h < p->n_heads; h++) {
            // get the query vector for this head
            floate* q = s->q + h * head_size;
            // attention scores for this head
            floate* att = s->att + h * p->seq_len;
            // iterate over all timesteps, including the current one
            for (int t = 0; t <= pos; t++) {
                // printf("get the key vector for this head and at this timestep\r\n");
                floate* k = s->key_cache + loff + t * kv_dim + (h / kv_mul) * head_size;
                // printf("calculate the attention score as the dot product of q and k\r\n");
                floate score = initfe(0,0,0);
                for (int i = 0; i < head_size; i++) {
                    score = addf(score, mulf(q[i] , k[i]));
                }
                score = mulf(score,invsqrtff(itofe(head_size)));
                // printf("save the score to the attention buffer\r\n");
                att[t] = score;
            }

            // printf("softmax the scores to get attention weights, from 0..pos inclusively\r\n");
            softmax(att, pos + 1);

            // printf("weighted sum of the values, store back into xb\r\n");
            floate* xb = s->xb + h * head_size;
            memset(xb, 0, head_size * sizeof(floate));
            for (int t = 0; t <= pos; t++) {
                // get the value vector for this head and at this timestep
                floate* v = s->value_cache + loff + t * kv_dim + (h / kv_mul) * head_size;
                // get the attention weight for this timestep
                floate a = att[t];
                // accumulate the weighted value into xb
                for (int i = 0; i < head_size; i++) {
                    xb[i] = addf(xb[i], mulf(a , v[i]));
                }
            }
        }
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("FORWARD (Layer %d) - multihead attention, iterate over all heads took %d seconds\r\n", l , timer_diff);


        // printf("final matmul to get the output of the attention\r\n");
        timer_start = timer;
        matmul(s->xb2, s->xb, w->wo + l*dim*dim, dim, dim);
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("FORWARD (Layer %d) - final matmul to get the output of the attention took %d seconds\r\n", l , timer_diff);


        // printf("residual connection back into x\r\n");
        timer_start = timer;
        for (int i = 0; i < dim; i++) {
            x[i] = addf(x[i], s->xb2[i]);
        }
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("FORWARD (Layer %d) - residual connection back into x took %d seconds\r\n", l , timer_diff);


        // printf("ffn rmsnorm\r\n");
        timer_start = timer;
        rmsnorm(s->xb, x, w->rms_ffn_weight + l*dim, dim);
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("FORWARD (Layer %d) - ffn rmsnorm took %d seconds\r\n", l , timer_diff);


        // printf("Now for FFN in PyTorch we have: self.w2(F.silu(self.w1(x)) * self.w3(x))\r\n");
        // first calculate self.w1(x) and self.w3(x)
        timer_start = timer;
        matmul(s->hb, s->xb, w->w1 + l*dim*hidden_dim, dim, hidden_dim);
        matmul(s->hb2, s->xb, w->w3 + l*dim*hidden_dim, dim, hidden_dim);
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("FORWARD (Layer %d) - FFN matmul took %d seconds\r\n", l , timer_diff);


        // printf("SwiGLU non-linearity\r\n");
        timer_start = timer;
        for (int i = 0; i < hidden_dim; i++) {
            floate val = s->hb[i];
            // silu(x)=x*σ(x), where σ(x) is the logistic sigmoid
            val = mulf(val, divf(initfe(0,127,0) , addf(initfe(0,127,0) ,expff(subf(initfe(0,0,0),val)))));
            // elementwise multiply with w3(x)
            val = mulf(val,s->hb2[i]);
            s->hb[i] = val;
        }
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("FORWARD (Layer %d) - SwiGLU non-linearity took %d seconds\r\n", l , timer_diff);


        // printf("final matmul to get the output of the ffn\r\n");
        timer_start = timer;
        matmul(s->xb, s->hb, w->w2 + l*dim*hidden_dim, hidden_dim, dim);
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("FORWARD (Layer %d) - final matmul to get the output of the ffn took %d seconds\r\n", l , timer_diff);

        // printf("residual connection\r\n");
        timer_start = timer;
        for (int i = 0; i < dim; i++) {
            x[i] = addf(x[i],s->xb[i]);
        }
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("FORWARD (Layer %d) - residual connection took %d seconds\r\n", l , timer_diff);
    }

    // printf("final rmsnorm\r\n");
    timer_start = timer;
    rmsnorm(x, x, w->rms_final_weight, dim);
    // timer_stop = timer;
    // timer_diff = (timer_stop-timer_start)/1000000;
    // printf("FORWARD - final rmsnorm took %d seconds\r\n", timer_diff);

    // printf("classifier into logits\r\n");
    timer_start = timer;
    matmul(s->logits, x, w->wcls, p->dim, p->vocab_size);
    // timer_stop = timer;
    // timer_diff = (timer_stop-timer_start)/1000000;
    // printf("FORWARD - classifier into logits took %d seconds\r\n", timer_diff); 


    // printf("Done - returning logits\r\n");
    return s->logits;
}

// ----------------------------------------------------------------------------
// The Byte Pair Encoding (BPE) Tokenizer that translates strings <-> tokens

typedef struct {
    char *str;
    int id;
} TokenIndex;

typedef struct {
    char** vocab;
    floate* vocab_scores;
    TokenIndex *sorted_vocab;
    int vocab_size;
    unsigned int max_token_length;
    unsigned char byte_pieces[512]; // stores all single-byte strings
} Tokenizer;

int compare_tokens(const void *a, const void *b) {
    return strcmp(((TokenIndex*)a)->str, ((TokenIndex*)b)->str);
}



void build_tokenizer(Tokenizer* t, int vocab_size) {
    // i should have written the vocab_size into the tokenizer file... sigh
    t->vocab_size = vocab_size;
    // malloc space to hold the scores and the strings
    t->vocab = (char**)malloc(vocab_size * sizeof(char*));
    t->vocab_scores = (floate*)malloc(vocab_size * sizeof(floate));
    // for (int i=0; i < vocab_size; i++)
    //   printf("%d \n\r",t->vocab_scores[i]);
    t->sorted_vocab = NULL; // initialized lazily
    for (int i = 0; i < 256; i++) {
        t->byte_pieces[i * 2] = (unsigned char)i;
        t->byte_pieces[i * 2 + 1] = '\0';
    }
    uint8_t* src = tokenizer_data;
    // sdprintblock(src);
    // printf("\n\r");
    t->max_token_length = ((int*)src)[0];
    // printf("Max token length: %d\r\n",t->max_token_length);
    // printf("Vocab size: %d\r\n",vocab_size);
    src += 4;
    int len;
    for (int i = 0; i < vocab_size; i++) {
        uint32_t a = src[0];
        uint32_t b = src[1];
        uint32_t c = src[2];
        uint32_t d = src[3];
        floate y = (d << 24) | (c << 16) |(b << 8) | a; 
        t->vocab_scores[i] = y;//((floate*)src)[0];
        src += 4;
        a = src[0];
        b = src[1];
        c = src[2];
        d = src[3];
        len = (d << 24) | (c << 16) |(b << 8) | a; 
        src += 4;
        t->vocab[i] = (char *)malloc(len + 1);
        for (int j = 0; j < len; j++){
            t->vocab[i][j] = src[j];
        }
        src += len;
        t->vocab[i][len] = '\0'; // add the string terminating token
    }
}

void free_tokenizer(Tokenizer* t) {
    for (int i = 0; i < t->vocab_size; i++) { free(t->vocab[i]); }
    free(t->vocab);
    free(t->vocab_scores);
    free(t->sorted_vocab);
}

char* decode(Tokenizer* t, int prev_token, int token) {
    char *piece = t->vocab[token];
    // following BOS (1) token, sentencepiece decoder strips any leading whitespace (see PR #89)
    if (prev_token == 1 && piece[0] == ' ') { piece++; }
    // careful, some tokens designate raw bytes, and look like e.g. '<0x01>'
    // parse this and convert and return the actual byte
    unsigned char byte_val;
    if (sscanf(piece, "<0x%02hhX>", &byte_val) == 1) {
        piece = (char*)t->byte_pieces + byte_val * 2;
    }
    return piece;
}

void safe_printf(char *piece) {
    // piece might be a raw byte token, and we only want to print printable chars or whitespace
    // because some of the other bytes can be various control codes, backspace, etc.
    if (piece == NULL) { return; }
    if (piece[0] == '\0') { return; }
    if (piece[1] == '\0') {
        unsigned char byte_val = piece[0];
        if (!(isprint(byte_val) || isspace(byte_val))) {
            return; // bad byte, don't print it
        }
    }
    printf("%s\n\r", piece);
}

int str_lookup(char *str, TokenIndex *sorted_vocab, int vocab_size) {
    // efficiently find the perfect match for str in vocab, return its index or -1 if not found
    TokenIndex tok = { .str = str }; // acts as the key to search for
    TokenIndex *res = bsearch(&tok, sorted_vocab, vocab_size, sizeof(TokenIndex), compare_tokens);
    return res != NULL ? res->id : -1;
}

void encode(Tokenizer* t, char *text, int8_t bos, int8_t eos, int *tokens, int *n_tokens) {
    // encode the string text (input) into an upper-bound preallocated tokens[] array
    // bos != 0 means prepend the BOS token (=1), eos != 0 means append the EOS token (=2)
    if (text == NULL) { printf( "cannot encode NULL text\n"); exit(EXIT_FAILURE); }

    if (t->sorted_vocab == NULL) {
        // lazily malloc and sort the vocabulary
        t->sorted_vocab = malloc(t->vocab_size * sizeof(TokenIndex));
        for (int i = 0; i < t->vocab_size; i++) {
            t->sorted_vocab[i].str = t->vocab[i];
            t->sorted_vocab[i].id = i;
        }
        qsort(t->sorted_vocab, t->vocab_size, sizeof(TokenIndex), compare_tokens);
    }

    // create a temporary buffer that will store merge candidates of always two consecutive tokens
    // *2 for concat, +1 for null terminator +2 for UTF8 (in case max_token_length is 1)
    char* str_buffer = malloc((t->max_token_length*2 +1 +2) * sizeof(char));
    size_t str_len = 0;

    // start at 0 tokens
    *n_tokens = 0;

    // add optional BOS (=1) token, if desired
    if (bos) tokens[(*n_tokens)++] = 1;

    // add_dummy_prefix is true by default
    // so prepend a dummy prefix token to the input string, but only if text != ""
    // TODO: pretty sure this isn't correct in the general case but I don't have the
    // energy to read more of the sentencepiece code to figure out what it's doing
    if (text[0] != '\0') {
        int dummy_prefix = str_lookup(" ", t->sorted_vocab, t->vocab_size);
        tokens[(*n_tokens)++] = dummy_prefix;
    }

    // Okay UTF-8 time. This will get messy. Here is the reference from Wikipedia:
    // Code point ↔ UTF-8 conversion
    // First code point Last code point Byte 1  Byte 2  Byte 3  Byte 4
    // U+0000 U+007F      0xxxxxxx
    // U+0080 U+07FF      110xxxxx  10xxxxxx
    // U+0800 U+FFFF      1110xxxx  10xxxxxx  10xxxxxx
    // U+10000  U+10FFFF    11110xxx  10xxxxxx  10xxxxxx  10xxxxxx

    // process the raw (UTF-8) byte sequence of the input string
    for (char *c = text; *c != '\0'; c++) {

        // reset buffer if the current byte is ASCII or a leading byte
        // 0xC0 is 11000000, so (*c & 0xC0) keeps the first 2 bits and zeros the rest
        // 0x80 is 10000000
        // in UTF-8, all continuation bytes start with "10" in first two bits
        // so in English this is: "if this byte is not a continuation byte"
        if ((*c & 0xC0) != 0x80) {
            // this byte must be either a leading byte (11...) or an ASCII char (0x...)
            // => reset our location, as we're starting a new UTF-8 codepoint
            str_len = 0;
        }

        // append the current byte to the buffer
        str_buffer[str_len++] = *c; // ++ is post-increment, incremented after this line
        str_buffer[str_len] = '\0';

        // while the next character is a continuation byte, continue appending
        // but if there are too many of them, just stop to avoid overruning str_buffer size.
        if ((*(c+1) & 0xC0) == 0x80 && str_len < 4) {
            continue;
        }

        // ok c+1 is not a continuation byte, so we've read in a full codepoint
        int id = str_lookup(str_buffer, t->sorted_vocab, t->vocab_size);

        if (id != -1) {
            // we found this codepoint in vocab, add it as a token
            tokens[(*n_tokens)++] = id;
        } else {
            // byte_fallback encoding: just encode each byte as a token
            // +3 is here because the first 3 vocab elements are <unk>, <s>, </s>
            // so the individual bytes only start at index 3
            for (int i=0; i < str_len; i++) {
                tokens[(*n_tokens)++] = (unsigned char)str_buffer[i] + 3;
            }
        }
        str_len = 0; // protect against a sequence of stray UTF8 continuation bytes
    }

    // merge the best consecutive pair each iteration, according the scores in vocab_scores
    while (1) {
        floate best_score = initfe(1,160,1377017); //-1e10;
        int best_id = -1;
        int best_idx = -1;

        for (int i=0; i < (*n_tokens-1); i++) {
            // check if we can merge the pair (tokens[i], tokens[i+1])
            sprintf(str_buffer, "%s%s", t->vocab[tokens[i]], t->vocab[tokens[i+1]]);
            int id = str_lookup(str_buffer, t->sorted_vocab, t->vocab_size);
            if (id != -1 && gtf(t->vocab_scores[id] , best_score)) {
                // this merge pair exists in vocab! record its score and position
                best_score = t->vocab_scores[id];
                best_id = id;
                best_idx = i;
            }
        }

        if (best_idx == -1) {
            break; // we couldn't find any more pairs to merge, so we're done
        }

        // merge the consecutive pair (best_idx, best_idx+1) into new token best_id
        tokens[best_idx] = best_id;
        // delete token at position best_idx+1, shift the entire sequence back 1
        for (int i = best_idx+1; i < (*n_tokens-1); i++) {
            tokens[i] = tokens[i+1];
        }
        (*n_tokens)--; // token length decreased
    }

    // add optional EOS (=2) token, if desired
    if (eos) tokens[(*n_tokens)++] = 2;

    free(str_buffer);
}

// ----------------------------------------------------------------------------
// The Sampler, which takes logits and returns a sampled token
// sampling can be done in a few ways: greedy argmax, sampling, top-p sampling

typedef struct {
    floate prob;
    int index;
} ProbIndex; // struct used when sorting probabilities during top-p sampling

typedef struct {
    int vocab_size;
    ProbIndex* probindex; // buffer used in top-p sampling
    floate temperature;
    floate topp;
    unsigned int rng_state;
} Sampler;

int sample_argmax(floate* probabilities, int n) {
    // return the index that has the highest probability
    int max_i = 0;
    floate max_p = probabilities[0];
    for (int i = 1; i < n; i++) {
        if (gtf(probabilities[i] , max_p)) {
            max_i = i;
            max_p = probabilities[i];
        }
    }
    return max_i;
}

int sample_mult(floate* probabilities, int n, floate coin) {
    // sample index from probabilities (they must sum to 1!)
    // coin is a random number in [0, 1), usually from random_f32()
    floate cdf = initfe(0,0,0);
    for (int i = 0; i < n; i++) {
        cdf = addf(cdf,probabilities[i]);
        if (ltf(coin , cdf)) {
            return i;
        }
    }
    return n - 1; // in case of rounding errors
}

int compare(const void* a, const void* b) {
    ProbIndex* a_ = (ProbIndex*) a;
    ProbIndex* b_ = (ProbIndex*) b;
    if (gtf(a_->prob , b_->prob)) return -1;
    if (ltf(a_->prob , b_->prob)) return 1;
    return 0;
}

int sample_topp(floate* probabilities, int n, floate topp, ProbIndex* probindex, floate coin) {
    // top-p sampling (or "nucleus sampling") samples from the smallest set of
    // tokens that exceed probability topp. This way we never sample tokens that
    // have very low probabilities and are less likely to go "off the rails".
    // coin is a random number in [0, 1), usually from random_f32()

    int n0 = 0;
    // quicksort indices in descending order of probabilities
    // values smaller than (1 - topp) / (n - 1) cannot be part of the result
    // so for efficiency we crop these out as candidates before sorting
    const floate cutoff = divfi(subf(initfe(0,127,0) , topp) , (n - 1));
    for (int i = 0; i < n; i++) {
        if (gtef(probabilities[i] , cutoff)) {
            probindex[n0].index = i;
            probindex[n0].prob = probabilities[i];
            n0++;
        }
    }
    qsort(probindex, n0, sizeof(ProbIndex), compare);

    // truncate the list where cumulative probability exceeds topp
    floate cumulative_prob = initfe(0,0,0);
    int last_idx = n0 - 1; // in case of rounding errors consider all elements
    for (int i = 0; i < n0; i++) {
        cumulative_prob = addf(cumulative_prob, probindex[i].prob);
        if (gtf(cumulative_prob , topp)) {
            last_idx = i;
            break; // we've exceeded topp by including last_idx
        }
    }

    // sample from the truncated list
    floate r = mulf(coin , cumulative_prob);
    floate cdf = initfe(0,0,0);
    for (int i = 0; i <= last_idx; i++) {
        cdf = addf(cdf, probindex[i].prob);
        if (ltf(r , cdf)) {
            return probindex[i].index;
        }
    }
    return probindex[last_idx].index; // in case of rounding errors
}

void build_sampler(Sampler* sampler, int vocab_size, floate temperature, floate topp, unsigned int rng_seed) {
    sampler->vocab_size = vocab_size;
    sampler->temperature = temperature;
    sampler->topp = topp;
    sampler->rng_state = rng_seed;
    // buffer only used with nucleus sampling; may not need but it's ~small
    sampler->probindex = malloc(sampler->vocab_size * sizeof(ProbIndex));
}

void free_sampler(Sampler* sampler) {
    free(sampler->probindex);
}

unsigned int random_u32(unsigned int *state) {
    // xorshift rng: https://en.wikipedia.org/wiki/Xorshift#xorshift.2A
    *state ^= *state >> 12;
    *state ^= *state << 25;
    *state ^= *state >> 27;
    return (*state * 0x2545F491);//4F6CDD1Dull) >> 32;
}
floate random_f32(unsigned int *state) { // random floate32 in [0,1)
    return divf(itofe(random_u32(state) >> 8) , initfe(0,151,0));
}

int sample(Sampler* sampler, floate* logits) {
    // sample the token given the logits and some hyperparameters
    int next;
    if (eqf(sampler->temperature , initfe(0,0,0))) {
        // greedy argmax sampling: take the token with the highest probability
        next = sample_argmax(logits, sampler->vocab_size);
    } else {
        // apply the temperature to the logits
        for (int q=0; q<sampler->vocab_size; q++) { logits[q] = divf(logits[q], sampler->temperature); }
        // apply softmax to the logits to get the probabilities for next token
        softmax(logits, sampler->vocab_size);
        // flip a (floate) coin (this is our source of entropy for sampling)
        floate coin = random_f32(&sampler->rng_state);
        // we sample from this distribution to get the next token
        if (ltef(sampler->topp, initfe(0,0,0)) || gtef(sampler->topp, initfe(0,127,0))) {
            // simply sample from the predicted probability distribution
            next = sample_mult(logits, sampler->vocab_size, coin);
        } else {
            // top-p (nucleus) sampling, clamping the least likely tokens to zero
            next = sample_topp(logits, sampler->vocab_size, sampler->topp, sampler->probindex, coin);
        }
    }
    return next;
}


// ----------------------------------------------------------------------------
// generation loop

void generate(Transformer *transformer, Tokenizer *tokenizer, Sampler *sampler, char *prompt, int steps) {

    uint32_t timer_start,timer_stop,timer_diff;
    // printf("In generate\n\r");
    char *empty_prompt = "";
    if (prompt == NULL) { prompt = empty_prompt; }

    // encode the (string) prompt into tokens sequence
    timer_start = timer;
    int num_prompt_tokens = 0;
    int* prompt_tokens = (int*)malloc((strlen(prompt)+3) * sizeof(int)); // +3 for '\0', ?BOS, ?EOS
    encode(tokenizer, prompt, 1, 0, prompt_tokens, &num_prompt_tokens);
    // printf("Done with encode: tokens: %d\n\r", num_prompt_tokens);
    if (num_prompt_tokens < 1) {
        printf( "something is wrong, expected at least 1 prompt token\n");
        exit(EXIT_FAILURE);
    }
    // timer_stop = timer;
    // timer_diff = (timer_stop-timer_start)/1000000;
    // printf("GENERATE - encode the (string) prompt into tokens sequence took %d seconds\r\n", timer_diff);

    // start the main loop
    int start = 0;  // used to time our code, only initialized after first iteration
    int next;        // will store the next token in the sequence
    int token = prompt_tokens[0]; // kick off with the first token in the prompt
    int pos = 0;     // position in the sequence
    while (pos < steps) {
        // printf("%d of %d\n\r", pos, steps);
        // printf("Doing forward\n\r");
        // forward the transformer to get logits for the next token
        timer_start = timer;
        floate* logits = forward(transformer, token, pos);
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("GENERATE - forward the transformer to get logits for the next token took %d seconds\r\n", timer_diff);



        // advance the state machine
        timer_start = timer;
        if (pos < num_prompt_tokens - 1) {
            // if we are still processing the input prompt, force the next prompt token
            next = prompt_tokens[pos + 1];
        } else {
            // otherwise sample the next token from the logits
            next = sample(sampler, logits);
        }
        pos++;
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("GENERATE - advance the state machine took %d seconds\r\n", timer_diff);

        // data-dependent terminating condition: the BOS (=1) token delimits sequences
        if (next == 1) { break; }


        timer_start = timer;
        // print the token as string, decode it with the Tokenizer object
        char* piece = decode(tokenizer, token, next);
        // timer_stop = timer;
        // timer_diff = (timer_stop-timer_start)/1000000;
        // printf("GENERATE - print the token as string, decode it with the Tokenizer object took %d seconds\r\n", timer_diff);


        safe_printf(piece); // same as printf("%s", piece), but skips "unsafe" bytes


        token = next;
    }
    printf("\n");

    // report achieved tok/s (pos-1 because the timer starts after first iteration)
    free(prompt_tokens);
}



int main() {
    printf("Hello World\n\r"); 
    model_data = (uint8_t*) malloc(MODEL_SIZE*sizeof(uint8_t));
    tokenizer_data = (uint8_t*) malloc(TOKENIZER_SIZE*sizeof(uint8_t)); //[TOKENIZER_SIZE];
    spi_speed = SPI_SLOW;
    while (SD_init() != SD_SUCCESS){
        printf("Card not detected\n\r");
        delay(1000);
    }  
    printf("Card initialized\n\r");
    spi_speed = SPI_FAST;
    load_files();
    printf("Loaded files\n\r");
    // default parameters
    floate temperature = initfe(0,127,0);   // 0.0 = greedy deterministic. 1.0 = original. don't set higher
    floate topp = initfe(0,126,6710886); //0.9f;          // top-p in nucleus sampling. 1.0 = off. 0.9 works well, but slower
    int steps = 256;            // number of steps to run for
    char *prompt = NULL;        // prompt string
    unsigned int rng_seed = 0; // seed rng with time by default

    // parameter validation/overrides
    if (ltf(temperature , initfe(0,0,0))) temperature = initfe(0,0,0);
    if (ltf(topp , initfe(0,0,0)) || ltf(initfe(0,127,0) , topp)) topp = initfe(0,126,6710886);
    if (steps < 0) steps = 0;

    printf("Building Transformer\n\r");
    // build the Transformer via the model .bin file
    Transformer transformer;
    build_transformer(&transformer);
    if (steps == 0 || steps > transformer.config.seq_len) steps = transformer.config.seq_len; // override to ~max length

    printf("Building Tokenizer\n\r");
    // build the Tokenizer via the tokenizer .bin file
    Tokenizer tokenizer;
    build_tokenizer(&tokenizer, transformer.config.vocab_size);

    printf("Building Sampler\n\r");
    // build the Sampler
    Sampler sampler;
    build_sampler(&sampler, transformer.config.vocab_size, temperature, topp, rng_seed);
    printf("run!\n\r");
    generate(&transformer, &tokenizer, &sampler, prompt, steps);
    
    // memory and file handles cleanup
    free_sampler(&sampler);
    free_tokenizer(&tokenizer);
    free_transformer(&transformer);
    while(1);
}
