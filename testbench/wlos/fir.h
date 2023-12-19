#ifndef __FIR_H__
#define __FIR_H__

#define N 11
#define SEQ_LEN 64

int taps[N] = {0,-10,-9,23,56,63,56,23,-9,-10,0};
int inputbuffer[N];
int inputsignal[N] = {1,2,3,4,5,6,7,8,9,10,11};
#ifdef wlos_act
int outputsignal[SEQ_LEN];
#else
int outputsignal[N];
#endif
#endif
