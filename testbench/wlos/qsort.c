#include "qsort.h"
#include <defs.h>

#define QSORT_CTRL  (*(volatile uint32_t*)0x30000200)
#define QSORT_IN    (*(volatile uint32_t*)0x30000280)
#define QSORT_OUT   (*(volatile uint32_t*)0x30000284)


#ifdef wlos_act
int* __attribute__ ( ( section ( ".mprjram" ) ) ) qsort(){
	volatile int32_t* ptr = &QSORT_IN;
	
	while(!((QSORT_CTRL &(0x00000002)) == 0x00000000)); //wait AP_idle
	QSORT_CTRL = 0x00000001; //ap_start
	
	for(int i=0; i< SIZE; i++){
		*(ptr) = Q[i];
	}
	
	while(!((QSORT_CTRL &(0x00000002)) == 0x00000000)); //wait AP_done

	ptr = &QSORT_OUT;
	for (int i=0; i<SIZE; i++){
		Q[i] = *(ptr);
	}
	return Q;
}
/*
int __attribute__ ( ( section ( ".mprjram" ) ) ) partition(int low,int hi){
	int pivot = Q[hi];
	int i = low-1,j;
	int temp;
	for(j = low;j<hi;j++){
		if(Q[j] < pivot){
			i = i+1;
			temp = Q[i];
			Q[i] = Q[j];
			Q[j] = temp;
		}
	}
	if(Q[hi] < Q[i+1]){
		temp = Q[i+1];
		Q[i+1] = Q[hi];
		Q[hi] = temp;
	}
	return i+1;
}

void __attribute__ ( ( section ( ".mprjram" ) ) ) sort(int low, int hi){
	if(low < hi){
		int p = partition(low, hi);
		sort(low,p-1);
		sort(p+1,hi);
	}
}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) qsort(){
	sort(0,SIZE-1);
	return Q;
}
*/
#else

int __attribute__ ( ( section ( ".mprjram" ) ) ) partition(int low,int hi){
	int pivot = Q[hi];
	int i = low-1,j;
	int temp;
	for(j = low;j<hi;j++){
		if(Q[j] < pivot){
			i = i+1;
			temp = Q[i];
			Q[i] = Q[j];
			Q[j] = temp;
		}
	}
	if(Q[hi] < Q[i+1]){
		temp = Q[i+1];
		Q[i+1] = Q[hi];
		Q[hi] = temp;
	}
	return i+1;
}

void __attribute__ ( ( section ( ".mprjram" ) ) ) sort(int low, int hi){
	if(low < hi){
		int p = partition(low, hi);
		sort(low,p-1);
		sort(p+1,hi);
	}
}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) qsort(){
	sort(0,SIZE-1);
	return Q;
}

#endif




