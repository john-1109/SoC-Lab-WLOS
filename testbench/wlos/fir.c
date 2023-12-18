#include "fir.h"
#include <defs.h>

#define FIR_CTRL  (*(volatile uint32_t*)0x30000300)
#define DATA_LEN  (*(volatile uint32_t*)0x30000310)
#define FIR_COEF  (*(volatile uint32_t*)0x30000340)
#define FIR_X     (*(volatile uint32_t*)0x30000380)
#define FIR_Y     (*(volatile uint32_t*)0x30000384)

#define COEF_PTR ((volatile int32_t*)0x30000340)


#ifdef wlos_act

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {
	//initial your fir
}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir(){
	initfir();
	//write down your fir
	
	DATA_LEN = 600;
	reg_mprj_datal = 0xA3000000;
	volatile int32_t* ptr = COEF_PTR;

	for(int i=0; i< 11; i++){
		*(ptr + i) = taps[i];
	}
	// // coef read check
	// for(int i=0; i< 11; i++){
	// 	reg_mprj_datal = *(ptr + i) << 16;
	// }

	while(!((FIR_CTRL &(0x00000002)) == 0x00000000)); //wait AP_idle
	FIR_CTRL = 0x00000001; //ap_start
	reg_mprj_datal = 0xA30F0000;

	int x = 1;
	bool plus = true;
	// for (int i=0; i<600; i=i+1) {

	// 	FIR_X = x;
	// 	reg_mprj_datal = FIR_Y << 16;

	// 	if(x == 75){plus = false;}
	// 	else if(x == -75){plus = true;}

	// 	if(plus){x++;}
	// 	else{x--;}
	// }

	FIR_X = 1;
	reg_mprj_datal = 0xA3F00000;
	reg_mprj_datal = FIR_Y << 16;

	for(int i=2; i<75; i=i+1) {
	    FIR_X = i;
	    reg_mprj_datal = FIR_Y << 16;
	}
	for(int i=75; i>-75; i=i-1) {
	    FIR_X = i;
	    reg_mprj_datal = FIR_Y << 16;
	}
	for(int i=-75; i<75; i=i+1) {
	    FIR_X = i;
	    reg_mprj_datal = FIR_Y << 16;
	}
	for(int i=75; i>-75; i=i-1) {
	    FIR_X = i;
	    reg_mprj_datal = FIR_Y << 16;
	}
	for(int i=-75; i<=0; i=i+1) {
	    FIR_X = i;
	    reg_mprj_datal = FIR_Y << 16;
	}
	reg_mprj_datal = 0xA3FF0000;

	// for(int looptime = 0; looptime < 3; looptime++){

	// }
	return outputsignal;
}

#else

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {
	for(int i=0; i<N; i++) {
		inputbuffer[i] = 0;
		outputsignal[i] = 0;
	}
}

int __attribute__ ( ( section ( ".mprjram" ) ) ) firfilter(int inputsample){
	for(int i=N-1; i>0; i--){
		inputbuffer[i] = inputbuffer[i-1];
	}
	inputbuffer[0] = inputsample;
	
	int outputsample = 0;
	for(int i=0; i<N; i++){
		outputsample += taps[i]*inputbuffer[i];
	}
	return outputsample;
}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir(){
	initfir();
	for(int i=0; i<N; i++){
		outputsignal[i] = firfilter(inputsignal[i]);
	}
	return outputsignal;
}

#endif

