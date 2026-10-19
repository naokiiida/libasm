NAME       := libasm.a

SRCS       := ft_strlen.s ft_strcpy.s ft_strcmp.s ft_write.s \
              ft_read.s ft_strdup.s ft_calloc.s
OBJS       := $(SRCS:.s=.o)

BONUS_SRCS := ft_atoi_base_bonus.s ft_list_push_front_bonus.s \
              ft_list_size_bonus.s ft_list_sort_bonus.s \
              ft_list_remove_if_bonus.s ft_simd_memchr_bonus.s
BONUS_OBJS := $(BONUS_SRCS:.s=.o)

NASM       := nasm
NASMFLAGS  := -f elf64
CC         := cc
CFLAGS     := -Wall -Wextra -Werror
AR         := ar
ARFLAGS    := rcs

all: $(NAME)

$(NAME): $(OBJS)
	$(AR) $(ARFLAGS) $@ $(OBJS)

%.o: %.s
	$(NASM) $(NASMFLAGS) $< -o $@

bonus: $(OBJS) $(BONUS_OBJS)
	$(AR) $(ARFLAGS) $(NAME) $(OBJS) $(BONUS_OBJS)

test: $(NAME) main.c libasm.h
	$(CC) $(CFLAGS) main.c -L. -lasm -o test
	./test $(FILTER)
	LIBASM_UNDER_VALGRIND=1 valgrind --leak-check=full --show-leak-kinds=all --error-exitcode=1 ./test $(FILTER)

clean:
	rm -f $(OBJS) $(BONUS_OBJS)

fclean: clean
	rm -f $(NAME) test

re: fclean all

dev:
	nix develop .#devShells.x86_64-linux.default

.PHONY: all bonus test clean fclean re dev
