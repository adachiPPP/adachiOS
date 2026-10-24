#include "../alibc/alibc.h"

int ga[3] = {10, 20, 30};
char gc = 'Q';

int main(void) {
    int x;
    int *p;
    int i;
    int sum;

    x = 7;
    p = &x;
    *p = 9;
    printf("x=%d sizeof(int)=%d sizeof(char)=%d gc=%c\r\n",
           x, sizeof(int), sizeof(char), gc);

    sum = 0;
    for (int j = 0; j < 3; j = j + 1) {
        sum = sum + ga[j];
    }
    printf("sum=%d\r\n", sum);
    printf("neg=%d %d %u\r\n", -5, -1234, 65535);

    for (i = 0; i < 10; i = i + 1) {
        if (i == 3) continue;
        if (i == 6) break;
        printf("%d ", i);
    }
    printf("\r\n");
    return 0;
}
