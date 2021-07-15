// global variables
int a,b,c[5];

void set_c(int i)
{
	a++;
	b--;
	c[i % 5] = a * b;
}

// recursion

int fib(int n)
{
    if (n <= 1)
        return n;
    return fib(n-1) + fib(n-2);
}
int fact(int n)
{
	if(n == 0)
		return 1;
	else 
		return n * fact(n-1);
}
int f1(int a)
{
	return a * a;
}
int f2(int b)
{
	// calls another function
	return b + f1(b);
}


int main()
{
	int a, b, i, f, x, y, arr[5];
	
	// expressions
	a = 1*(2+3)%3;  
    	b = 1<5;
    	x = (b != 1);
    	
    	println(a);  // a = 2
    	println(b);  // b = 1
    	println(x);  // c = 0
    	
    	// unary operators
    	a = (!b) + (-a);
    	println(a);  // a = -2
    	
	// for loop
	for(i=0;i<5;i++)
	{
		set_c(i);
		x = c[i];
		println(x); // c = {-1, -4, -9, -16, -25}
	}
	
	x = 10;
	y = 20;
	
	// conditional
	if(x >= y)
	{
		for(i=0;i<5;i++)
		{
			arr[i] = c[i];
		}
	}
	else  // this branch
	{
		
		for(i=0;i<5;i++)
		{
			arr[i] = c[4-i];
		}
	}
	
	i = 0;
	// while loop
	while(i < 5)
	{
		x = arr[i];
		println(x); // arr = {-25, -16, -9, -4, -1}
		i++; 
	}
	
	
	// function call
	x = f2(5) + f1(3);
	println(x); // x = 5*5 + 5 + 3*3 = 39
	
	y = f2(f2(2));
	println(y);  // y = (2*2 + 2) * (2*2 + 2) + (2*2 + 2) = 42
	
	// recursive function call
	f = fact(5);
	println(f);  // f = 5! = 120
	
	
}
