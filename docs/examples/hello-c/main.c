/* hello-c — пример программы для сборки RPM из исходников.
 * Скомпилируется командой gcc прямо во время сборки пакета
 * (секция %build в RPM Builder). */
#include <stdio.h>

int main(void)
{
    printf("Привет из hello-c 1.0!\n");
    printf("Эта программа была скомпилирована во время сборки RPM.\n");
    return 0;
}
