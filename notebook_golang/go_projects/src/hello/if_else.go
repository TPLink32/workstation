package main

import "fmt"

func main() {
	if 7 % 2 == 0 {
		fmt.Println("7是偶数")
	} else {
		fmt.Println("7是奇数")
	}

	if 8 % 4 == 0 {
		fmt.Println("8可以被4整除")
	}

	if num := 9; num < 0 {
		fmt.Println(num, "is negative")
	} else if num < 10 {
		fmt.Println(num, "has 1 digit")
	} else {
		fmt.Println(num, "has multiple digits")
	}
}