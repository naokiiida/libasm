## Mandatory part
• The library must be called libasm.a.
• You must submit a main function that will test your functions and compile with your library to demonstrate that it is functional.
• You must rewrite the following functions in assembly:
  ◦ ft_strlen (man 3 strlen)
  ◦ ft_strcpy (man 3 strcpy)
  ◦ ft_strcmp (man 3 strcmp)
  ◦ ft_write (man 2 write)
  ◦ ft_read (man 2 read)
  ◦ ft_strdup (man 3 strdup, you can call to malloc)
  ◦ ft_calloc (man 3 calloc, you can call to malloc; you must detect and handle a size_t overflow in nmemb * size yourself, instead of relying on malloc to
catch it)
• You must check for errors during syscalls and handle them properly when needed.
• Your code must set the variable errno properly.
• For that, you are allowed to call the extern ___error or errno_location.

## Bonus part

You can rewrite these functions in assembly. The linked list functions will use the follow-
ing structure:
```c
typedef struct s_list
{
  void *data;
  struct s_list *next;
} t_list;
```

• ft_atoi_base (see Annex VII.1)
• ft_list_push_front (see Annex VII.2)
• ft_list_size (see Annex VII.3)
• ft_list_sort (see Annex VII.4)
• ft_list_remove_if (see Annex VII.5)
• ft_simd_memchr (see Annex VII.6)
