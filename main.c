#include "libasm.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define C_RESET  "\033[0m"
#define C_GREEN  "\033[32m"
#define C_RED    "\033[31m"
#define C_YELLOW "\033[33m"
#define C_CYAN   "\033[36m"

static int	g_passed = 0;
static int	g_failed = 0;
static int	g_skipped = 0;

static void	check(int cond, const char *suite, const char *desc)
{
	if (cond)
	{
		g_passed++;
		printf("  " C_GREEN "[PASS]" C_RESET " %s: %s\n", suite, desc);
	}
	else
	{
		g_failed++;
		printf("  " C_RED "[FAIL]" C_RESET " %s: %s\n", suite, desc);
	}
}

static int	sign_of(int x)
{
	return ((x > 0) - (x < 0));
}

/*
** ============================================================================
** 1. ft_strlen
** ============================================================================
*/
static void	test_strlen(void)
{
	printf(C_CYAN "\n=== Testing ft_strlen ===" C_RESET "\n");
	check(ft_strlen("") == strlen(""), "ft_strlen", "empty string \"\"");
	check(ft_strlen("a") == strlen("a"), "ft_strlen", "single char \"a\"");
	check(ft_strlen("42 Tokyo libasm") == strlen("42 Tokyo libasm"),
		"ft_strlen", "normal string");
	check(ft_strlen("embedded\0null") == strlen("embedded\0null"),
		"ft_strlen", "stops at first NUL byte");

	char	long_str[4096];
	memset(long_str, 'x', sizeof(long_str) - 1);
	long_str[sizeof(long_str) - 1] = '\0';
	check(ft_strlen(long_str) == 4095, "ft_strlen", "4095-byte buffer");
}

/*
** ============================================================================
** 2. ft_strcpy
** ============================================================================
*/
static void	test_strcpy(void)
{
	printf(C_CYAN "\n=== Testing ft_strcpy ===" C_RESET "\n");
	char	dst1[64];
	char	dst2[64];
	char	*ret;

	memset(dst1, 0x7f, sizeof(dst1));
	memset(dst2, 0x7f, sizeof(dst2));
	ret = ft_strcpy(dst1, "");
	strcpy(dst2, "");
	check(ret == dst1 && dst1[0] == '\0' && dst1[1] == 0x7f,
		"ft_strcpy", "empty string copies NUL and returns dst");

	memset(dst1, 0x7f, sizeof(dst1));
	memset(dst2, 0x7f, sizeof(dst2));
	ret = ft_strcpy(dst1, "Hello, x86-64 NASM!");
	strcpy(dst2, "Hello, x86-64 NASM!");
	check(ret == dst1 && strcmp(dst1, dst2) == 0
		&& dst1[strlen(dst2) + 1] == 0x7f,
		"ft_strcpy", "normal string + NUL termination without overrun");
}

/*
** ============================================================================
** 3. ft_strcmp
** ============================================================================
*/
static void	test_strcmp(void)
{
	printf(C_CYAN "\n=== Testing ft_strcmp ===" C_RESET "\n");
	check(ft_strcmp("", "") == 0, "ft_strcmp", "both empty \"\" vs \"\"");
	check(sign_of(ft_strcmp("", "a")) == sign_of(strcmp("", "a")),
		"ft_strcmp", "\"\" vs \"a\" (< 0)");
	check(sign_of(ft_strcmp("a", "")) == sign_of(strcmp("a", "")),
		"ft_strcmp", "\"a\" vs \"\" (> 0)");
	check(ft_strcmp("42libasm", "42libasm") == 0,
		"ft_strcmp", "identical strings");
	check(sign_of(ft_strcmp("abc", "abd")) == sign_of(strcmp("abc", "abd")),
		"ft_strcmp", "\"abc\" vs \"abd\" (< 0)");
	check(sign_of(ft_strcmp("abd", "abc")) == sign_of(strcmp("abd", "abc")),
		"ft_strcmp", "\"abd\" vs \"abc\" (> 0)");
	check(sign_of(ft_strcmp("abc", "abcd")) == sign_of(strcmp("abc", "abcd")),
		"ft_strcmp", "prefix \"abc\" vs \"abcd\" (< 0)");
	check(sign_of(ft_strcmp("\xff", "\x01")) == sign_of(strcmp("\xff", "\x01")),
		"ft_strcmp", "unsigned char comparison \"\\xff\" (255) vs \"\\x01\" (1)");
	check(sign_of(ft_strcmp("\x01", "\x80")) == sign_of(strcmp("\x01", "\x80")),
		"ft_strcmp", "unsigned char comparison \"\\x01\" (1) vs \"\\x80\" (128)");
}

/*
** ============================================================================
** 4. ft_write
** ============================================================================
*/
static void	test_write(void)
{
	printf(C_CYAN "\n=== Testing ft_write ===" C_RESET "\n");
	int		fds[2];
	char	buf[32];
	ssize_t	ret;

	if (pipe(fds) != 0)
		return ;
	errno = 0;
	ret = ft_write(fds[1], "libasm_write_ok", 15);
	memset(buf, 0, sizeof(buf));
	ssize_t r = read(fds[0], buf, sizeof(buf));
	check(ret == 15 && r == 15 && strcmp(buf, "libasm_write_ok") == 0
		&& errno == 0, "ft_write", "writes 15 bytes to pipe with errno == 0");

	errno = 0;
	ret = ft_write(fds[1], "anything", 0);
	check(ret == 0 && errno == 0, "ft_write", "count == 0 returns 0");

	errno = 0;
	ret = ft_write(-1, "bad_fd", 6);
	check(ret == -1 && errno == EBADF,
		"ft_write", "invalid fd (-1) returns -1 and sets errno = EBADF");

	if (!getenv("LIBASM_UNDER_VALGRIND"))
	{
		errno = 0;
		ret = ft_write(fds[1], NULL, 5);
		check(ret == -1 && errno == EFAULT,
			"ft_write", "NULL buffer returns -1 and sets errno = EFAULT");
	}

	close(fds[0]);
	close(fds[1]);
}

/*
** ============================================================================
** 5. ft_read
** ============================================================================
*/
static void	test_read(void)
{
	printf(C_CYAN "\n=== Testing ft_read ===" C_RESET "\n");
	int		fds[2];
	char	buf[32];
	ssize_t	ret;

	if (pipe(fds) != 0)
		return ;
	if (write(fds[1], "libasm_read_ok", 14) != 14)
	{
		close(fds[0]);
		close(fds[1]);
		return ;
	}
	memset(buf, 0, sizeof(buf));
	errno = 0;
	ret = ft_read(fds[0], buf, 14);
	check(ret == 14 && strcmp(buf, "libasm_read_ok") == 0 && errno == 0,
		"ft_read", "reads 14 bytes from pipe with errno == 0");

	errno = 0;
	ret = ft_read(fds[0], buf, 0);
	check(ret == 0 && errno == 0, "ft_read", "count == 0 returns 0");

	errno = 0;
	ret = ft_read(-1, buf, 5);
	check(ret == -1 && errno == EBADF,
		"ft_read", "invalid fd (-1) returns -1 and sets errno = EBADF");

	if (!getenv("LIBASM_UNDER_VALGRIND") && write(fds[1], "x", 1) == 1)
	{
		errno = 0;
		ret = ft_read(fds[0], NULL, 1);
		check(ret == -1 && errno == EFAULT,
			"ft_read", "NULL buffer returns -1 and sets errno = EFAULT");
	}
	close(fds[0]);
	close(fds[1]);
}

/*
** ============================================================================
** 6. ft_strdup
** ============================================================================
*/
static void	test_strdup(void)
{
	printf(C_CYAN "\n=== Testing ft_strdup ===" C_RESET "\n");
	const char	*src1 = "";
	char		*dup1 = ft_strdup(src1);
	check(dup1 != NULL && dup1 != src1 && strcmp(dup1, "") == 0,
		"ft_strdup", "empty string \"\"");
	free(dup1);

	const char	*src2 = "Duplicated via malloc in x86-64 assembly!";
	char		*dup2 = ft_strdup(src2);
	check(dup2 != NULL && dup2 != src2 && strcmp(dup2, src2) == 0,
		"ft_strdup", "normal string matches content and distinct address");
	free(dup2);
}

/*
** ============================================================================
** 7. ft_calloc
** ============================================================================
*/
static void	test_calloc(void)
{
	printf(C_CYAN "\n=== Testing ft_calloc ===" C_RESET "\n");
	/* Dirty heap memory first to make sure ft_calloc actually zeros memory */
	unsigned char	*dirty = malloc(128);
	if (dirty)
	{
		memset(dirty, 0xAA, 128);
		free(dirty);
	}
	unsigned char	*mem = ft_calloc(32, sizeof(uint32_t));
	int				all_zero = (mem != NULL);
	for (size_t i = 0; mem && i < 32 * sizeof(uint32_t); i++)
	{
		if (mem[i] != 0)
			all_zero = 0;
	}
	check(all_zero, "ft_calloc", "allocates and zero-initializes 128 bytes");
	free(mem);

	void	*zero_alloc = ft_calloc(0, 16);
	check(zero_alloc != NULL || errno == 0,
		"ft_calloc", "nmemb == 0 handled cleanly");
	free(zero_alloc);

	errno = 0;
	void	*ovf1 = ft_calloc(SIZE_MAX, 2);
	check(ovf1 == NULL && errno == ENOMEM,
		"ft_calloc", "detects overflow (SIZE_MAX * 2) and sets errno = ENOMEM");

	errno = 0;
	void	*ovf2 = ft_calloc((size_t)1ULL << 33, (size_t)1ULL << 32);
	check(ovf2 == NULL && errno == ENOMEM,
		"ft_calloc", "detects 64-bit wrap-around ((1<<33) * (1<<32) == 2^65)");
}

/*
** ============================================================================
** Bonus Part Tests
** ============================================================================
*/
static int	cmp_str_wrapper(void *a, void *b)
{
	return (strcmp((const char *)a, (const char *)b));
}

static int	g_free_count = 0;
static void	record_free(void *data)
{
	(void)data;
	g_free_count++;
}

static void	test_bonus(void)
{
	printf(C_CYAN "\n=== Testing Bonus Functions ===" C_RESET "\n");
	if (ft_atoi_base)
	{
		check(ft_atoi_base("42", "0123456789") == 42,
			"ft_atoi_base", "\"42\" in base 10");
		check(ft_atoi_base("   ---+--+101010", "01") == -42,
			"ft_atoi_base", "whitespace + multiple signs in binary");
		check(ft_atoi_base("2a", "0123456789abcdef") == 42,
			"ft_atoi_base", "\"2a\" in hex");
		check(ft_atoi_base("42", "0") == 0
			&& ft_atoi_base("42", "01230") == 0
			&& ft_atoi_base("42", "01+2") == 0
			&& ft_atoi_base("42", "01 2") == 0,
			"ft_atoi_base", "invalid bases (len<2, dup, '+', space) return 0");
	}
	else
	{
		g_skipped++;
		printf("  " C_YELLOW "[SKIP]" C_RESET " ft_atoi_base not linked yet\n");
	}

	if (ft_list_push_front && ft_list_size)
	{
		t_list	*head = NULL;
		check(ft_list_size(head) == 0, "ft_list_size", "empty list -> 0");
		ft_list_push_front(&head, "c");
		ft_list_push_front(&head, "a");
		ft_list_push_front(&head, "b");
		check(ft_list_size(head) == 3
			&& strcmp(head->data, "b") == 0
			&& strcmp(head->next->data, "a") == 0
			&& strcmp(head->next->next->data, "c") == 0,
			"ft_list_push_front", "pushes 3 elements in LIFO order");

		if (ft_list_sort)
		{
			ft_list_sort(&head, cmp_str_wrapper);
			check(strcmp(head->data, "a") == 0
				&& strcmp(head->next->data, "b") == 0
				&& strcmp(head->next->next->data, "c") == 0,
				"ft_list_sort", "sorts [\"b\", \"a\", \"c\"] -> [\"a\", \"b\", \"c\"]");
		}
		else
			printf("  " C_YELLOW "[SKIP]" C_RESET " ft_list_sort not linked yet\n");

		if (ft_list_remove_if)
		{
			g_free_count = 0;
			ft_list_remove_if(&head, "b", cmp_str_wrapper, record_free);
			check(ft_list_size(head) == 2 && g_free_count == 1
				&& strcmp(head->data, "a") == 0
				&& strcmp(head->next->data, "c") == 0,
				"ft_list_remove_if", "removes middle node \"b\"");
		}
		else
			printf("  " C_YELLOW "[SKIP]" C_RESET " ft_list_remove_if not linked yet\n");

		while (head)
		{
			t_list *tmp = head->next;
			free(head);
			head = tmp;
		}
	}
	else
	{
		g_skipped++;
		printf("  " C_YELLOW "[SKIP]" C_RESET
			" ft_list_push_front / ft_list_size not linked yet\n");
	}

	if (ft_simd_memchr)
	{
		const char	buf[64] = "0123456789abcdef0123456789ABCDEF!target_byte!";
		check(ft_simd_memchr(buf, '!', sizeof(buf)) == memchr(buf, '!', sizeof(buf)),
			"ft_simd_memchr", "finds '!' at offset 32");
		check(ft_simd_memchr(buf + 3, 'A', 40) == memchr(buf + 3, 'A', 40),
			"ft_simd_memchr", "unaligned start pointer (buf + 3)");
		check(ft_simd_memchr(buf, 'Z', sizeof(buf)) == NULL,
			"ft_simd_memchr", "returns NULL when byte not found");
	}
	else
	{
		g_skipped++;
		printf("  " C_YELLOW "[SKIP]" C_RESET " ft_simd_memchr not linked yet\n");
	}
}

int	main(int argc, char **argv)
{
	const char	*filter = (argc > 1) ? argv[1] : "all";

	if (strcmp(filter, "all") == 0 || strcmp(filter, "strlen") == 0)
		test_strlen();
	if (strcmp(filter, "all") == 0 || strcmp(filter, "strcpy") == 0)
		test_strcpy();
	if (strcmp(filter, "all") == 0 || strcmp(filter, "strcmp") == 0)
		test_strcmp();
	if (strcmp(filter, "all") == 0 || strcmp(filter, "write") == 0)
		test_write();
	if (strcmp(filter, "all") == 0 || strcmp(filter, "read") == 0)
		test_read();
	if (strcmp(filter, "all") == 0 || strcmp(filter, "strdup") == 0)
		test_strdup();
	if (strcmp(filter, "all") == 0 || strcmp(filter, "calloc") == 0)
		test_calloc();
	if (strcmp(filter, "all") == 0 || strcmp(filter, "bonus") == 0)
		test_bonus();

	printf("\n============================================\n");
	printf("Summary: " C_GREEN "%d passed" C_RESET ", "
		C_RED "%d failed" C_RESET ", "
		C_YELLOW "%d skipped" C_RESET "\n",
		g_passed, g_failed, g_skipped);
	printf("============================================\n");
	return (g_failed > 0 ? 1 : 0);
}
