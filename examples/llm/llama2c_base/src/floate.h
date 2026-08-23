// log approximation knob - affects performance and the story - 10000 gives the inbuilt logf result. 
#define LN_ITERATIONS 1000

////////////////////////////// Data structures ////////////////////////

typedef struct {
    unsigned int sign;
    unsigned int exponent;
    unsigned int mantissa;
} floate_s;

typedef unsigned int floate;

//////////////////////////////// Helper functions ///////////////////////////
floate festofe(floate_s a){
	int ret = ((a.sign&1) << 31) | ((a.exponent&255) << 23) | (a.mantissa&8388607);
	return ret;
}

floate_s fetofes(floate a){
	unsigned int field =  a;
	floate_s ret;
	ret.sign = (field >> 31) & 1;
	ret.exponent = (field >> 23) & 255;
	ret.mantissa = field & 0x7FFFFF;
    return ret;
}

unsigned int festoi(floate_s f){
	return  ((f.sign&1) << 31) | ((f.exponent&255) << 23) | (f.mantissa&8388607);
}

floate_s initfes(unsigned int sign, unsigned int exponent, unsigned int mantissa){
	floate_s ret;
	ret.sign = sign;
	ret.exponent = exponent;
	ret.mantissa = mantissa;
	return ret;
}

floate initfe(unsigned int sign, unsigned int exponent, unsigned int mantissa){
	floate_s ret;
	ret.sign = sign;
	ret.exponent = exponent;
	ret.mantissa = mantissa;
	return festofe(ret);
}

unsigned int floatestouint(unsigned int exponent, unsigned int  mantissa) {
    int  actual_exponent = exponent - 127 - 23;
    mantissa = mantissa | 0x800000;
    if (exponent < 127) {
		return 0;
	}
	if (actual_exponent > 7){
		return 0xFFFFFFFF;
	}
    if (actual_exponent < 0)
		mantissa >>= -actual_exponent;
	else if (actual_exponent > 0)
		mantissa <<= actual_exponent;
    return mantissa;
}

floate_s itofes(int a){
	floate_s ret;
	ret.sign = (a < 0) ? 1 : 0;
	if (a == 0){
		ret.exponent = 0;
		ret.mantissa = 0;
	}
	else {
		if (a<0)
			a = 0-a;
		int i = 0;
		for (i=30; i>=0; i--){
			if ((a>>i)&1){
				break;
			}
		}
		ret.exponent = 127 + i;
		ret.mantissa = a;

		while (ret.mantissa >= (1<<25)){
			int lsb = ret.mantissa&1;
			ret.mantissa >>= 1;
			ret.mantissa += lsb;
		}
		while (ret.mantissa < (1<<23)){
			ret.mantissa <<= 1;
		}
		ret.mantissa &= ((1<<24)-1);
	}
	return ret;
}

floate itofe(unsigned int a){
	return festoi(itofes(a));
}

floate_s ietofes(unsigned int a){
    floate_s ret;
	ret.sign = (a >> 31) & 1;
	ret.exponent = (a >> 23) & 255;
	ret.mantissa = a & 0x7FFFFF;
    return ret;
}

//////////////////////////// FP functions ////////////////////////////////

floate addf(floate a, floate b){
	floate c;
    __asm__ (".insn r 0x2B , 0x0, 0x0, %[rd] , %[rs1], %[rs2]" : [rd] "=r" (c) : [rs1] "r" (a), [rs2] "r" (b));
    return c;
	// floate_s _a, _b, _c;
	// unsigned int normalize_target = 0x800000;
	// _a = fetofes(a);
	// _b = fetofes(b);
    // if  (_a.exponent == 0 && _a.mantissa == 0){
    //     return b;
    // }
    // if (_b.exponent == 0 && _b.mantissa == 0){
    //     return a;
    // }
	// _a.mantissa = _a.mantissa|0x800000;
	// _b.mantissa = _b.mantissa|0x800000;
    // while (_a.exponent > _b.exponent) {
    // 	int lsb = _b.mantissa&1;
    //     _b.mantissa >>= 1;
    //     _b.exponent += 1;
    //     _b.mantissa += lsb;
    // } 
    // while (_a.exponent < _b.exponent){
    // 	int lsb = _a.mantissa&1;
    //     _a.mantissa >>= 1;
    //     _a.exponent += 1; 
    //     _a.mantissa += lsb;
    // }
    // _c.exponent = _a.exponent;
    // if ((_a.sign != _b.sign) && (_a.mantissa == _b.mantissa)){
    // 	_c.exponent = 0;
    // 	_c.mantissa = 0;
    // }
    // else {
	// 	if (_a.sign == _b.sign){
	// 		_c.sign = _a.sign;
	// 		_c.mantissa = _a.mantissa + _b.mantissa;
	// 		int lsb;
	// 		if (_c.mantissa >= (normalize_target << 1)){
	// 			lsb = _c.mantissa&1;
	// 			_c.mantissa >>= 1;
	// 			_c.exponent += 1;
	// 			if (lsb)
	// 				_c.mantissa += 1;
	// 		}		
	// 		if (_c.mantissa >= (normalize_target << 1)){
	// 			_c.mantissa >>= 1;
	// 			_c.exponent += 1;	
	// 		}
	// 	}
	// 	else {
	// 		if (_a.mantissa >= _b.mantissa){
	// 			_c.sign = _a.sign;
	// 			_c.mantissa = _a.mantissa - _b.mantissa;
	// 		}
	// 		else {
	// 			_c.sign = _b.sign;
	// 			_c.mantissa = _b.mantissa - _a.mantissa;
	// 		}

	// 		while (_c.mantissa < normalize_target){
	// 			_c.mantissa <<= 1;
	// 			_c.exponent -= 1;
	// 		}
	// 	}
	// 	_c.mantissa &= (normalize_target-1);
	// }
	// return festofe(_c);
}

floate subf(floate a, floate b){
	floate_s _b,_c;
	_b = fetofes(b);
	_b.sign ^= 1;
	return (addf(a,festofe(_b)));
}

floate mulf(floate a, floate b){
	floate c;
    __asm__ (".insn r 0x2B , 0, 0x1, %[rd] , %[rs1], %[rs2]" : [rd] "=r" (c) : [rs1] "r" (a), [rs2] "r" (b));
    return c;
// 	floate_s _a, _b, _c;
// 	_a = fetofes(a);
// 	_b = fetofes(b);
   // if ((_a.exponent == 0) || (_b.exponent == 0)){
   //  _c.sign = 0;
   //  _c.exponent = 0;
   //  _c.mantissa = 0;
   //  }
   //  else {
   //  	_c.sign = (_a.sign == _b.sign) ? 0 : 1;
   //  	unsigned int normalize_target = 0x800000;
   //  	int _ae = _a.exponent-127;
   //  	int _be = _b.exponent-127;
   //  	_c.exponent = (_ae + _be)+127;
   //  	_a.mantissa = _a.mantissa|0x800000;
   //  	_b.mantissa = _b.mantissa|0x800000;
   //  	unsigned long long int mul_res =  (unsigned long long int)_a.mantissa * (unsigned long long int)_b.mantissa;
// 		unsigned long long int mask = 0xFFFFFFFFFF000000;
// 		mul_res >>= 22;
// 		int lsb = mul_res&1;
// 		mul_res >>= 1;
// 		mul_res += lsb;	
// 		if (mul_res & mask){
// 			mul_res >>= 1;
// 			_c.exponent += 1;
// 		}
// 		_c.mantissa = (unsigned int) mul_res;
// 		_c.mantissa &= (normalize_target-1);
// 	}
// 	return festofe(_c);
}

floate divf(floate a, floate b){
	floate c;
    __asm__ (".insn r 0x2B , 0, 0x2, %[rd] , %[rs1], %[rs2]" : [rd] "=r" (c) : [rs1] "r" (a), [rs2] "r" (b));
    return c;
// 	floate_s _a, _b, _c;
// 	_a = fetofes(a);
// 	_b = fetofes(b);
   // if ((_a.exponent == 0) || (_b.exponent == 0)){
   //  _c.sign = 0;
   //  _c.exponent = 0;
   //  _c.mantissa = 0;
   //  }
   //  else {
   //     _c.sign = (_a.sign == _b.sign) ? 0 : 1;
   //      unsigned int normalize_target = 0x800000;
   //      int _ae = _a.exponent - 127;
   //      int _be = _b.exponent - 127;
   //      _c.exponent = (_ae - _be) + 127;
   //      _a.mantissa = _a.mantissa | 0x800000;
   //      _b.mantissa = _b.mantissa | 0x800000;
   //      unsigned long long int div_res = ((unsigned long long int)_a.mantissa << 23) / _b.mantissa;
   //      unsigned int mask = 0xFF800000;
   //      while (!(div_res & 0x800000)) {
   //          div_res <<= 1;
   //          _c.exponent -= 1;
   //      }
   //      _c.mantissa = (unsigned int)(div_res & 0x7FFFFF); 
   //  }
   //  return festofe(_c);
}

floate divfi(floate a, int b){
	floate _b = itofe(b);
	return divf(a,_b);
}

int eqf(floate a, floate b){
	floate_s _a, _b;
	_a = fetofes(a);
	_b = fetofes(b);
	return ((_a.exponent == _b.exponent) && (_a.mantissa == _b.mantissa) && (_a.sign == _b.sign));
}

int gtf(floate a, floate b){
	floate_s _a, _b;
	_a = fetofes(a);
	_b = fetofes(b);
	if (eqf(a,b)) return 0;
	if (_a.sign < _b.sign) return 1;
	if (_a.sign > _b.sign) return 0;
	if (_a.sign){
		if (_a.exponent > _b.exponent) return 0;
		if (_a.exponent < _b.exponent) return 1;
		if (_a.mantissa > _b.mantissa) return 0;
		return 1;
	}
	else{
		if (_a.exponent > _b.exponent) return 1;
		if (_a.exponent < _b.exponent) return 0;
		if (_a.mantissa > _b.mantissa) return 1;
		return 0;
	}
}

int ltf(floate a, floate b){
	floate_s _a, _b;
	_a = fetofes(a);
	_b = fetofes(b);
	if (eqf(a,b)) return 0;
	if (_a.sign < _b.sign) return 0;
	if (_a.sign > _b.sign) return 1;
	if (_a.sign){
		if (_a.exponent > _b.exponent) return 1;
		if (_a.exponent < _b.exponent) return 0;
		if (_a.mantissa > _b.mantissa) return 1;
		return 0;
	}
	else{
		if (_a.exponent > _b.exponent) return 0;
		if (_a.exponent < _b.exponent) return 1;
		if (_a.mantissa > _b.mantissa) return 0;
		return 1;
	}
}

int gtef(floate a, floate b){
	return (eqf(a,b) || gtf(a,b));
}

int ltef(floate a, floate b){
	return (eqf(a,b) || ltf(a,b));
}

floate expff(floate x){
	floate result;
    __asm__ (".insn r 0x2B , 0, 0x4, %[rd] , %[rs1], %[rs2]" : [rd] "=r" (result) : [rs1] "r" (x), [rs2] "r" (x));
    return result;
	// //https://gist.github.com/jrade/293a73f89dfef51da6522428c857802d
    // floate a = initfe(0,150,3713595);
    // floate b = initfe(0,156,8251811);
    // x = addf(mulf(a, x),b);
    // floate c = initfe(0,150,0);
    // floate d = initfe(0,157,8323072);
    // if (ltf(x, c) || gtf(x, d))
    //     x = ltf(x , c) ? initfe(0,0,0) : d;
    // floate_s _x = fetofes(x);
    // unsigned int n = floatestouint(_x.exponent, _x.mantissa);
    // floate_s ret = ietofes(n);
    // return festofe(ret);
}

floate ffmod(floate x, floate mod) {
	floate q, result;
	floate_s _q;
	q = divf(x , mod);
	_q = fetofes(q);
    int quotient = _q.exponent >= 127 ? floatestouint(_q.exponent, _q.mantissa) : 0;
    quotient *= (_q.sign ? -1:1);
    result = subf(x , mulf(festofe(itofes(quotient)), mod));
    if (fetofes(result).exponent < 127) {
        result = addf(result,mod);
    }
    return result;
}

floate cosff(floate x){
	//https://www.ganssle.com/approx.htm
	floate mx = ffmod(x, initfe(0, 129, 4788187));
	if (ltf(mx , initfe(0, 0, 0))) 
		mx = addf(mx,initfe(0, 129, 4788187));
	floate c1 = initfe(0, 127, 0); // 0.9999999999999999999999914771;
	floate c2 = initfe(1, 126, 0); // -0.4999999999999999999991637437;
	floate c3 = initfe(0, 122, 2796203); // 0.04166666666666666665319411988;
	floate c4 = initfe(1, 117, 3541857); // -0.00138888888888888880310186415;
	floate c5 = initfe(0, 111, 5246209); // 0.00002480158730158702330045157;
	floate c6 = initfe(1, 105, 1307262); // -0.000000275573192239332256421489;
	floate c7 = initfe(0, 98, 1013447); // 0.000000002087675698165412591559;
	floate c8 = initfe(1, 90, 4836261); // -0.0000000000114707451267755432394;
	floate c9 = initfe(0, 82, 5717852); // 0.0000000000000477945439406649917;
	floate c10= initfe(1, 74, 3407685); // -0.00000000000000015612263428827781;
	floate c11= initfe(0, 65, 7051852); // 0.00000000000000000039912654507924;
	if (gtf(mx , initfe(0, 128, 4788187))) {
		mx = subf(mx,initfe(0, 128, 4788187));
		mx = subf(initfe(0, 128, 4788187) , mx);
	}
	floate x2 = mulf(mx,mx);
	floate res;
	res = addf(c10 , mulf(x2,c11));
	res = addf(c9, mulf(x2,res));
	res = addf(c8, mulf(x2,res));
	res = addf(c7, mulf(x2,res));
	res = addf(c6, mulf(x2,res));
	res = addf(c5, mulf(x2,res));
	res = addf(c4, mulf(x2,res));
	res = addf(c3, mulf(x2,res));
	res = addf(c2, mulf(x2,res));
	res = addf(c1, mulf(x2,res));
	return res;
}

floate sinff(floate x){
	return cosff(subf(x,initfe(0,127,4788187)));
}

floate invsqrtff(floate a){
	// floate result;
    // __asm__ (".insn r 0x2B , 0x5, 0, %[rd] , %[rs1], %[rs2]" : [rd] "=r" (result) : [rs1] "r" (a), [rs2] "r" (a));
    // return result;
 //https://www.geeksforgeeks.org/fast-inverse-square-root/
	floate half = initfe(0,126,0); //0.5f;
	floate threehalfs = initfe(0,127,4194304);//1.5f;
	floate x2 = mulf(a,half);
	floate y = a;
	floate_s _y = fetofes(y);
    unsigned int i =  festoi(_y);
	i = 0x5f3759df - (i >> 1);
	y = festofe(ietofes(i));
	y = mulf(y , subf(threehalfs , (mulf(mulf(x2 , y) , y))));
	return y;
}

// (powfi, logff, powff) https://gist.github.com/serg06/38760a4b5aceb4c6245d61c56716588c
floate powfi(floate x, unsigned p) {
    floate result = initfe(0,127,0);
    while (p) {
        if (p & 0x1) {
            result = mulf(result,x);
        }
        x = mulf(x,x);
        p >>= 1;
    }
    return result;
}

floate logff(floate x) {
	floate result;
    __asm__ (".insn r 0x2B , 0, 0x3, %[rd] , %[rs1], %[rs2]" : [rd] "=r" (result) : [rs1] "r" (x), [rs2] "r" (x));
    return result;
    // floate result = initfe(0,0,0);
    // for (int n = 1; n < LN_ITERATIONS; n++) {
    // 	floate two_n_minus_one = subf(mulf(initfe(0,128,0),itofe(n)),initfe(0,127,0));
    // 	floate ires = divf(subf(x,initfe(0,127,0)),addf(x,initfe(0,127,0)));
    // 	ires = powfi(ires,2*n-1);
    //     ires = divf(ires,two_n_minus_one);
    //     result = addf(result,ires);
    // }
    // return mulf(initfe(0,128,0),result);
}

floate powff(floate x, floate p){
	floate_s _p = fetofes(p);
    unsigned int int_power = _p.exponent >= 127 ? floatestouint(_p.exponent, _p.mantissa) : 0;
    floate int_pow_result = powfi(x, int_power);
    floate remaining_power = subf(p,itofe(int_power));
    floate remaining_result = expff(mulf(remaining_power,logff(x)));
    return mulf(int_pow_result,remaining_result);
}
