#include "mat.h"
#include <chrono>
#include <fstream>
#include <ios>
#include <iostream>
#include <stdio.h>
#include <string>
#include <vector>
#include <stdlib.h>
#include <time.h>
static int A_LEN = 0, B_LEN = 0;
#define M 3      
#define MM -3    
#define W -2     
//#define A_LEN 500
//#define B_LEN 500
#define max(a, b) (((a) > (b)) ? (a) : (b))
#define min(a, b) (((a) < (b)) ? (a) : (b))
__global__ void fill_gpu(Matrix h, Matrix d, char seqA[], char seqB[],const int *k);
time_t t;
 //  unsigned int tt = 1000;
   //srand(n);
void seq_gen(int n, char seq[]) {
   //time_t t;
   // unsigned int tt = 1000;
   //srand(n);
   //srand((unsigned) time(&t));
   //std::cout << " " << t << std::endl;
  for (int i = 0; i < n; i++) {
    int base = rand() % 4;
    switch (base) {
    case 0:
      seq[i] = 'A';
      break;
    case 1:
      seq[i] = 'T';
      break;
    case 2:
      seq[i] = 'C';
      break;
    case 3:
      seq[i] = 'G';
      break;
    }
  }
}

int fill_cpu(Matrix h, Matrix d, char seqA[], char seqB[]) {

  int full_max_id = 0;
  int full_max_val = 0;

  for (int i = 1; i < h.height; i++) {
    for (int j = 1; j < h.width; j++) {

      int max_score = 0;
      int direction = 0;
      int tmp_score;
      int sim_score;

      int id = i * h.width + j;                  
      int abov_id = (i - 1) * h.width + j;       
      int left_id = i * h.width + (j - 1);       
      int diag_id = (i - 1) * h.width + (j - 1); 

      tmp_score = h.elements[abov_id] + W;
      if (tmp_score > max_score) {
        max_score = tmp_score;
        direction = 1;
      }

      tmp_score = h.elements[left_id] + W;
      if (tmp_score > max_score) {
        max_score = tmp_score;
        direction = 2;
      }

      char baseA = seqA[j - 1];
      char baseB = seqB[i - 1];
      if (baseA == baseB) {
        sim_score = M;
      } else {
        sim_score = MM;
      }

      tmp_score = h.elements[diag_id] + sim_score;
      if (tmp_score >= max_score) {
        max_score = tmp_score;
        direction = 3;
      }

      h.elements[id] = max_score;
      d.elements[id] = direction;

      if (max_score > full_max_val) {
        full_max_id = id;
        full_max_val = max_score;
      }
    }
  }

  std::cout << "\nMax score of " << full_max_val;
  std::cout << " at id: " << full_max_id << std::endl;
  return full_max_id;
}

__global__ void fill_gpu(Matrix h, Matrix d, char seqA[], char seqB[], const int k, int max_id_val[],int alen,int blen) {

  int max_score = 0;
  int direction = 0;
  int tmp_score;
  int sim_score;

  int i = threadIdx.x + 1 + blockDim.x * blockIdx.x;
  if (k > alen + 1) {
    i += (k - alen);
  }
  int j = ((k) - i) + 1;
  int id = i * h.width + j;
  
  int abov_id = (i - 1) * h.width + j;       
  int left_id = i * h.width + (j - 1);       
  int diag_id = (i - 1) * h.width + (j - 1); 

  tmp_score = h.elements[abov_id] + W;
  if (tmp_score > max_score) {
    max_score = tmp_score;
    direction = 1;
  }

  tmp_score = h.elements[left_id] + W;
  if (tmp_score > max_score) {
    max_score = tmp_score;
    direction = 2;
  }

  char baseA = seqA[j - 1];
  char baseB = seqB[i - 1];
  if (baseA == baseB) {
    sim_score = M;
  } else {
    sim_score = MM;
  }

  tmp_score = h.elements[diag_id] + sim_score;
  if (tmp_score >= max_score) {
    max_score = tmp_score;
    direction = 3;
  }

  h.elements[id] = max_score;
  d.elements[id] = direction;

  if (max_score > max_id_val[1]) {
    max_id_val[0] = id;
    max_id_val[1] = max_score;
  }
}

void traceback(Matrix d, int max_id, char seqA[], char seqB[],std::vector<char> &seqA_aligned,std::vector<char> &seqB_aligned) {

  int max_i = max_id / d.width;
  int max_j = max_id % d.width;

  
  while (max_i > 0 && max_j > 0) {

    int id = max_i * d.width + max_j;
    int dir = d.elements[id];

    switch (dir) {
    case 1:
      --max_i;
      seqA_aligned.push_back('-');
      seqB_aligned.push_back(seqB[max_i]);
      break;
    case 2:
      --max_j;
      seqA_aligned.push_back(seqA[max_j]);
      seqB_aligned.push_back('-');
      break;
    case 3:
      --max_i;
      --max_j;
      seqA_aligned.push_back(seqA[max_j]);
      seqB_aligned.push_back(seqB[max_i]);
      break;
    case 0:
      max_i = -1;
      max_j = -1;
      break;
    }
  }
}

void io_seq(std::vector<char> &seqA_aligned, std::vector<char> &seqB_aligned) {

  std::cout << "Aligned sub-sequences of A and B: " << std::endl;
  int align_len = seqA_aligned.size();
  std::cout << "   ";
  for (int i = 0; i < align_len + 1; ++i) {
    std::cout << seqA_aligned[align_len - i];
  }
  std::cout << std::endl;

  std::cout << "   ";
  for (int i = 1; i < align_len + 1; ++i) {
    std::cout << seqB_aligned[align_len - i];
  }
  std::cout << std::endl << std::endl;
  
}

void io_score(std::string file, Matrix h, char seqA[], char seqB[]) {
  std::ofstream myfile_tsN;
  myfile_tsN.open(file);

  myfile_tsN << '\t' << '\t';
  for (int i = 0; i < A_LEN; i++)
    myfile_tsN << seqA[i] << '\t';
  myfile_tsN << std::endl;

  for (int i = 0; i < h.height; i++) {
    if (i == 0) {
      myfile_tsN << '\t';
    } else {
      myfile_tsN << seqB[i - 1] << '\t';
    }
    for (int j = 0; j < h.width; j++) {
      myfile_tsN << h.elements[i * h.width + j] << '\t';
    }
    myfile_tsN << std::endl;
  }
  myfile_tsN.close();
}

void smith_water_cpu(Matrix h, Matrix d, char seqA[], char seqB[]) {

  int max_id = fill_cpu(h, d, seqA, seqB);

  std::vector<char> seqA_aligned;
  std::vector<char> seqB_aligned;
  traceback(d, max_id, seqA, seqB, seqA_aligned, seqB_aligned);

  std::cout << std::endl;
  std::cout << "CPU result: " << std::endl;

  io_seq(seqA_aligned, seqB_aligned);

  io_score(std::string("data files/score.dat"), h, seqA, seqB);
  io_score(std::string("data files/direction.dat"), d, seqA, seqB);
}

void smith_water_gpu(Matrix h, Matrix d, char seqA[], char seqB[]) {

  std::cout << "GPU result: " << std::endl;

  char *d_seqA, *d_seqB;
  cudaMalloc(&d_seqA, A_LEN * sizeof(char));
  cudaMalloc(&d_seqB, B_LEN * sizeof(char));
  cudaMemcpy(d_seqA, seqA, A_LEN * sizeof(char), cudaMemcpyHostToDevice);
  cudaMemcpy(d_seqB, seqB, B_LEN * sizeof(char), cudaMemcpyHostToDevice);
  int Gpu = 1;

  Matrix d_h(A_LEN + 1, B_LEN + 1, Gpu);
  Matrix d_d(A_LEN + 1, B_LEN + 1, Gpu);
  d_h.load(h, Gpu);
  d_d.load(d, Gpu);

  int *d_max_id_val;                   
  std::vector<int> h_max_id_val(2, 0); 
  cudaMalloc(&d_max_id_val, 2 * sizeof(int)); 
  cudaMemcpy(d_max_id_val, h_max_id_val.data(), 2 * sizeof(int),cudaMemcpyHostToDevice);

  cudaEvent_t start, stop;
  float time;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  cudaEventRecord(start, 0);

 
  for (int i = 1; i <= ((A_LEN + 1) + (B_LEN + 1) - 1); i++) {
    
    int col_idx = max(0, (i - (B_LEN + 1)));
    int diag_len = min(i, ((A_LEN + 1) - col_idx));

    int blks = 32;
    if(diag_len / blks >= 1)  {
      dim3 dimBlock(diag_len / blks);
      dim3 dimGrid(blks);
      fill_gpu<<<dimGrid, dimBlock>>>(d_h, d_d, d_seqA, d_seqB, i, d_max_id_val,A_LEN,B_LEN);
    }
    else {
      dim3 dimBlock(diag_len);
      dim3 dimGrid(1);
      fill_gpu<<<dimGrid, dimBlock>>>(d_h, d_d, d_seqA, d_seqB, i,d_max_id_val, A_LEN, B_LEN);
    }

    cudaDeviceSynchronize();
  }
 
  size_t size = (A_LEN + 1) * (B_LEN + 1) * sizeof(float);
  cudaMemcpy(d.elements, d_d.elements, size, cudaMemcpyDeviceToHost);
  cudaMemcpy(h.elements, d_h.elements, size, cudaMemcpyDeviceToHost);
  cudaMemcpy(h_max_id_val.data(), d_max_id_val, 2 * sizeof(int),cudaMemcpyDeviceToHost);

  
  int max_id = h_max_id_val[0];
  std::vector<char> seqA_aligned;
  std::vector<char> seqB_aligned;
  traceback(d, max_id, seqA, seqB, seqA_aligned, seqB_aligned);

  cudaEventRecord(stop, 0);
  cudaEventSynchronize(stop);
  cudaEventElapsedTime(&time, start, stop);  

  io_seq(seqA_aligned, seqB_aligned);
  io_score(std::string("data files/score_gpu.dat"), h, seqA, seqB);
  io_score(std::string("data files/direction_gpu.dat"), d, seqA, seqB);

  std::cout << "   GPU time = " << time << " ms\n" << std::endl;

  d_h.gpu_deallocate();
  d_d.gpu_deallocate();
  cudaFree(d_seqA);
  cudaFree(d_seqB);
  cudaFree(d_max_id_val);
}

int main() {
  unsigned tt = (unsigned)time(&t);
  srand(tt);
  std::cout << "Enter length of sequence A: ";
  std::cin >> A_LEN;
  std::cout << "Enter length of sequence B: ";
  std::cin >> B_LEN;
  char seqA[10000];
  char seqB[10000];
  seq_gen(A_LEN, seqA);
  seq_gen(B_LEN, seqB);
 
  Matrix scr_cpu(A_LEN + 1, B_LEN + 1); 
  Matrix dir_cpu(A_LEN + 1, B_LEN + 1); 
  Matrix scr_gpu(A_LEN + 1, B_LEN + 1); 
  Matrix dir_gpu(A_LEN + 1, B_LEN + 1); 

  for (int i = 0; i < scr_cpu.height; i++) {
    for (int j = 0; j < scr_cpu.width; j++) {
      int id = i * scr_cpu.width + j;
      scr_cpu.elements[id] = 0;
      dir_cpu.elements[id] = 0;
      scr_gpu.elements[id] = 0;
      dir_gpu.elements[id] = 0;
    }
  }

  std::cout << "\nInput size is :" << A_LEN <<std:: endl;
  io_score(std::string("data files/init.dat"), scr_cpu, seqA, seqB);

  auto start_cpu = std::chrono::steady_clock::now();
  smith_water_cpu(scr_cpu, dir_cpu, seqA, seqB); 
  auto end_cpu = std::chrono::steady_clock::now();
  auto diff = end_cpu - start_cpu;
  std::cout << "   CPU time = "
            << std::chrono::duration<double, std::milli>(diff).count() << " ms"
            << std::endl;
  std::cout << std::endl;

  smith_water_gpu(scr_gpu, dir_gpu, seqA, seqB); 

  scr_cpu.cpu_deallocate();
  dir_cpu.cpu_deallocate();
  scr_gpu.cpu_deallocate();
  dir_gpu.cpu_deallocate();

  return 0;
}
