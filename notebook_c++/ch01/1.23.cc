#include <iostream>
#include "Sales_item.h"

int main()
{       
        Sales_item item1, item2;
        int count = 0;
        std::cin >> item1;
        while (std::cin >> item2)
        {
                if (item1.isbn() == item2.isbn())
                {
                        count++;
                        item1 += item2;
                }
                else
                {
                        std::cout << item1 << " " << count << std::endl;
                        count = 1;
                        item1 = item2;
                }
        }

        std::cout << item1 << " " << count << std::endl; 

        return 0;
}