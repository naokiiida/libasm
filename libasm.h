#ifndef LIBASM_H
# define LIBASM_H

# include <stddef.h>
# include <sys/types.h>

/*
** ============================================================================
** Mandatory Part
** ============================================================================
*/

size_t	ft_strlen(const char *s);
char	*ft_strcpy(char *dst, const char *src);
int		ft_strcmp(const char *s1, const char *s2);
ssize_t	ft_write(int fd, const void *buf, size_t count);
ssize_t	ft_read(int fd, void *buf, size_t count);
char	*ft_strdup(const char *s);
void	*ft_calloc(size_t nmemb, size_t size);

/*
** ============================================================================
** Bonus Part (marked weak so main.c links with both `make` and `make bonus`)
** ============================================================================
*/

typedef struct s_list
{
	void			*data;
	struct s_list	*next;
}	t_list;

# define LIBASM_BONUS_WEAK __attribute__((weak))

int		ft_atoi_base(char *str, char *base) LIBASM_BONUS_WEAK;
void	ft_list_push_front(t_list **begin_list, void *data) LIBASM_BONUS_WEAK;
int		ft_list_size(t_list *begin_list) LIBASM_BONUS_WEAK;
void	ft_list_sort(t_list **begin_list,
			int (*cmp)(void *, void *)) LIBASM_BONUS_WEAK;
void	ft_list_remove_if(t_list **begin_list, void *data_ref,
			int (*cmp)(void *, void *),
			void (*free_fct)(void *)) LIBASM_BONUS_WEAK;
void	*ft_simd_memchr(const void *s, int c, size_t n) LIBASM_BONUS_WEAK;

#endif
