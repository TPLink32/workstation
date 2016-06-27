#include <stdio.h>

#define IN	1
#define OUT	0

int main()
{
	int c, nl, nw, nc, state;
	state = OUT;
	nl = nc = nw = 0;

	while ((c = getchar()) != EOF)
	{
		++nc;
		if (c == '\n')
		{
			++nl;
		}

		if (c == ' ' || c == '\n' || c == '\t')
		{
			state = OUT;
		}
		else if (state == OUT)
		{
			state = IN;
			++nw;
		}
	}

	printf("nl = %d, nc = %d, nw = %d\n", nl, nc, nw);

	return 0;
}
