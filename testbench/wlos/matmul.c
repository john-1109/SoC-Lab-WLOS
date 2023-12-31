#include "matmul.h"
#include <defs.h>


#define MM_CTRL     (*(volatile uint32_t*)0x30000100)
#define MM_arrA     (*(volatile int32_t*)0x30000180)
#define MM_arrB     (*(volatile int32_t*)0x30000184)
#define MM_arrR     (*(volatile int32_t*)0x3000018C)

#ifdef wlos_act

int* __attribute__ ( ( section ( ".mprjram" ) ) ) matmul()
{
	volatile int32_t* ptr = &MM_arrB;

	
	while(!((MM_CTRL &(0x00000004)) == 0x00000004)); //wait AP_idle
	MM_CTRL = 0x00000001; //ap_start
	for(int i=0; i< SIZE; i++){
		*(ptr) = B[i*SIZE];
		*(ptr) = B[i*SIZE+1];
		*(ptr) = B[i*SIZE+2];
		*(ptr) = B[i*SIZE+3];
	}
	
	ptr = &MM_arrA;
	for(int i=0; i< SIZE; i++){
		*(ptr) = A[i*SIZE];
		*(ptr) = A[i*SIZE+1];
		*(ptr) = A[i*SIZE+2];
		*(ptr) = A[i*SIZE+3];
	}
	
	
	ptr = &MM_arrR;
	for (int i=0; i<SIZE; i++){
		result[i*SIZE] = *(ptr);
		result[i*SIZE+1] = *(ptr);
		result[i*SIZE+2] = *(ptr);
		result[i*SIZE+3] = *(ptr);
	}
	return result;
}
	
#else

int* __attribute__ ( ( section ( ".mprjram" ) ) ) matmul()
{
	int i=0;
	int j;
	int k;
	int sum;
	int kk;
	unsigned int count = 0;
	for (i=0; i<SIZE; i++){
		for (j=0; j<SIZE; j++){
			sum = 0;
			for(k = 0;k<SIZE;k++)
				sum += A[(i*SIZE) + k] * B[(k*SIZE) + j];
			result[(i*SIZE) + j] = sum;
		}
	}
	return result;
}

#endif


