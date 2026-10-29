/* Совместимость со старыми glibc (РЕД ОС 8, Astra и др.).
 *
 * Статические libstdc++/libgcc, собранные на новейшей системе, тянут
 * ссылки на символы, которых нет в более старых glibc:
 *   - __isoc23_strtoul  — добавлен в glibc 2.38 (C23-вариант strtoul);
 *   - _dl_find_object   — добавлен в glibc 2.35 (быстрый поиск EH-кадров).
 *
 * Эквиваленты:
 *   - strtoul без C23-расширений (отличия только в разборе 0b-литералов);
 *   - dl_find_object, всегда возвращающий «не найдено» (-1): libgcc
 *     переходит на резервный поиск unwind-информации (dl_iterate_phdr).
 *     Проверено тестом throw/catch: раскрутка стека работает.
 */
#include <stdlib.h>

unsigned long __isoc23_strtoul(const char *nptr, char **endptr, int base)
{
    return strtoul(nptr, endptr, base);
}

int _dl_find_object(const void *pc, void *out)
{
    (void)pc; (void)out;
    return -1;
}
