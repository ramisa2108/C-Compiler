#include<iostream>
#include<string>
#include<fstream>
#include "scopeTable.h"
using namespace std;


class symbolTable{

     scopeTable *currentScopeTable;
     int allScopeTableSize;

public:
    symbolTable(int tableSize){

        allScopeTableSize = tableSize;
        
        currentScopeTable = new scopeTable(tableSize);
    }
    void enterNewScope(){
        scopeTable *newScope = new scopeTable(allScopeTableSize, currentScopeTable);
        currentScopeTable = newScope;
        return ;
    }

    void exitScope(){
    
    	if(currentScopeTable == nullptr) return ;

        scopeTable *parentScope = currentScopeTable->getParentScope();
        delete currentScopeTable;
        currentScopeTable = parentScope;

    }

    bool insertIntoCurrentScope(string name, string type){
    	if(currentScopeTable == nullptr) return false;
        if(currentScopeTable->insertIntoTable(name, type)){
        	print("A");
        	return true;
        }
        return false;
        
    }

    bool removeFromCurrentScope(string name){
        return currentScopeTable->deleteFromTable(name);
    }

    symbolInfo *lookUp(string name){

        symbolInfo *symbolFound = nullptr;
        scopeTable *now = currentScopeTable;

        while(now != nullptr){
            symbolFound = now->lookUp(name);
            if(symbolFound != nullptr) break;
            now = now->getParentScope();
        }
        if(symbolFound == nullptr) cout << "Not found." << endl << endl;
        return symbolFound;

    }
    void print(string type){
    
    	if(currentScopeTable==nullptr) return ;

        if(type == "A")
        {
            scopeTable *now = currentScopeTable;
            while(now != nullptr){

                now->print();
                now = now->getParentScope();
            }
        }
        else if(type == "C"){
            if(currentScopeTable != nullptr) currentScopeTable->print();
        }
        return ;
    }
    ~symbolTable(){

        scopeTable *parentScope;

        while(currentScopeTable != nullptr){
            parentScope = currentScopeTable->getParentScope();
            delete currentScopeTable;
            currentScopeTable = parentScope;
        }


    }

};

