
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <sys/time.h>

int *unroll(int **ising, int n){
    int *ising1d = (int *)malloc(n * n * sizeof(int));
    for(int i = 0 ; i < n ; i++){
        for(int j = 0 ; j < n ; j++){
            ising1d[i*n + j] = ising[i][j];
        }
    }

    return ising1d;
}
void swap(int  **a, int  **b) {
  int  *tmp = *a;
  *a = *b;
  *b = tmp;
}

__global__ void moment(int *ising, int *newising, int n, int b){
      for(int i = ((blockIdx.x*1024 + threadIdx.x)*b/n)*b ; i < ((blockIdx.x*1024 + threadIdx.x)*b/n)*b + b; i++){
        for(int j = ((blockIdx.x*1024 + threadIdx.x)%(n/b))*b ; j < ((blockIdx.x*1024 + threadIdx.x)%(n/b))*b + b; j++){
          int sum = ising[i*n + j + n - n*n*(i==n-1)] + ising[i*n + j - n + n*n*(i==0)]
          + ising[i*n + j + 1 - n*(j%n == n - 1)]
          + ising[i*n + j - 1 + n*(j%n == 0)]
          + ising[i*n + j];
          if(sum > 0)
            newising[i*n + j] = 1 ;
          else
            newising[i*n + j] = -1 ;
        }
      }
}

int main(int argc, char **argv){

    //size of Ising model
    int n = 2048;
    // number of iterations
    int k = 100;

    srand(time(NULL));

    int *ising = (int *) malloc(n * n * sizeof(int));
    for(int i = 0 ; i < n ; i++){
        for(int j = 0 ; j < n ; j ++){
            ising[i*n + j] = rand() % 2 ;
            if(ising[i*n + j] == 0){
                ising[i*n + j] = -1;
            }
        }
    }

    /*for(int i = 0 ; i < n ; i++){
        for(int j = 0 ; j < n ; j++){
            printf("%d " , ising[i*n + j]);
        }
        printf("\n");
    }
    printf("\n");*/

    int *newising = (int *)malloc(n * n * sizeof(int));
    
    int *d_ising;
    int *d_newising;
    int size = n * n * sizeof(int);
    
    //allocate on gpu
    cudaMalloc((void**)&d_ising, size);
    cudaMalloc((void**)&d_newising, size);
    
    //b size
    int b = 32;

    int blocks = ((n*n/(b*b))-1)/1024 + 1;
    
    struct timeval start, end;
    double time;
    

    for(int l = 0 ; l < k ; l++){
        //copy data to gpu
        cudaMemcpy(d_ising, ising, size, cudaMemcpyHostToDevice);
        //call function on gpu with n*n threads
        gettimeofday(&start, NULL);
        moment<<<blocks,(n*n/(b*b))/blocks>>>(d_ising, d_newising, n, b);
        gettimeofday(&end, NULL);
        //copy result from gpu
        cudaMemcpy(newising, d_newising, size, cudaMemcpyDeviceToHost);
        time += (double)((end.tv_usec - start.tv_usec)/1.0e6 + end.tv_sec - start.tv_sec);

        swap(&ising,&newising);

       
    }

     /*for(int i = 0 ; i < n ; i++){
            for(int j = 0 ; j < n ; j++){
                printf("%d " , ising[i*n + j]);
            }
            printf("\n");
        }
        printf("\n");*/
        
    
    printf("time: %f\n", time);

    //free pointers
    free(ising);
    free(newising);
    cudaFree(d_ising);
    cudaFree(d_newising);
    return 0 ;
}
