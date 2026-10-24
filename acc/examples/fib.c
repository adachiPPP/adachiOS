#include "../alibc/alibc.h"

int fib(int n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

int main(void) {
    int i;
    for (i = 0; i < 12; i = i + 1) {
        printf("%d ", fib(i));
    }
    printf("\r\n");
    return 0;
}
