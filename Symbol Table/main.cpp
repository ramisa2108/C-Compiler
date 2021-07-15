#include<iostream>
#include<string>
#include<sstream>
#include "symbolTable.h"
using namespace std;

int main(int argc,char *argv[])
{

    if(argc != 2)
	{
		cout << "Please provide a file name" << endl;
		return 0;
	}

    freopen(argv[1], "r", stdin);
    freopen("output.txt", "w", stdout);
    int bucketSize;
    cin >> bucketSize;

    symbolTable *symTab = new symbolTable(bucketSize);
    string name, type, command, line;
    symbolInfo *foundSymbol;

    while(getline(cin, line)){

        stringstream ss(line);
        cout << line << endl << endl;

        ss >> command;

        if(command == "I"){
            ss >> name >> type;
            symTab->insertIntoCurrentScope(name, type);

        }
        else if(command == "L"){
            ss >> name;
            foundSymbol = symTab->lookUp(name);
        }
        else if(command == "D"){
            ss >> name;
            symTab->removeFromCurrentScope(name);
        }
        else if(command == "P"){
            ss >> type;
            symTab->print(type);
        }
        else if(command == "S"){
            symTab->enterNewScope();
        }
        else if(command == "E"){
            symTab->exitScope();

        }
        cout << endl;
    }
}
