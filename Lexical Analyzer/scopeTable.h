#include<iostream>
#include<string>
#include<fstream>
#include "symbolInfo.h"
using namespace std;


class scopeTable{

     int totalBuckets;
     symbolInfo **table;
     scopeTable* parentScope;
     string tableId;
     int children;
    
public:


    scopeTable(int n,  scopeTable *ps=nullptr){


        totalBuckets = n;
        table = new symbolInfo*[n];

        for(int i=0;i<n;i++)
            table[i] = nullptr;

        parentScope = ps;

        if(ps == nullptr)
            tableId = "1";
        else{
            tableId = ps->generateNextChildTableId();
	}
        children = 0;
        
        
    }

    void setParentScope(scopeTable *ps){
        parentScope = ps;
    }
    scopeTable *getParentScope(){
        return parentScope;
    }
    void setTableId(string id){
        tableId = id;
    }
    string getTableId(){
        return tableId;
    }

    string generateNextChildTableId(){

        string childTableId = tableId;
        children++;
        childTableId += "." + to_string(children);
        return childTableId;
    }

    bool insertIntoTable(string name, string type){

        int index = hashFunction(name);

        int position = -1;
        if(table[index] == nullptr){

            table[index] = new symbolInfo(name, type);
            position = 0;
        }

        else position = table[index]->extendChain(name, type);
	/*
        if(position == -1)
            cout << "< " << name << " : " << type << "> already exists in current ScopeTable." << endl << endl;
        else
            cout << "Inserted in ScopeTable #" << tableId << " at position " << index << ", " << position << endl << endl;
	*/
        return (position != -1);

    }

    symbolInfo *lookUp(string name){

        int index = hashFunction(name);
        int position = 0;
        symbolInfo *found = table[index]->searchSymbol(name, position);
        if(found != nullptr)
            cout << "Found in ScopeTable #" << tableId << " at position " << index << ", " << position << "." << endl << endl;
        return found;

    }

    bool deleteFromTable(string name){

        int index = hashFunction(name);
        int position = 0;
        symbolInfo *toDelete = table[index]->searchSymbol(name, position);

        if(toDelete == nullptr) {
            cout << name << " not found." << endl << endl;
            return false;
        }
        else {
            cout << "Deleted entry " << index << ", " << position << " from current ScopeTable." << endl << endl;
        }

        symbolInfo *parent = table[index]->findParent(name);

        if(parent == nullptr) table[index] = toDelete->getNextSymbolInfo();
        else parent->setNextSymbolInfo(toDelete->getNextSymbolInfo());

        toDelete->setNextSymbolInfo(nullptr);
        delete toDelete;

        return true;

    }

    int hashFunction(string name){
        int hashValue = 0;

        for(int i=0;i<name.length();i++){
            hashValue += (int) name[i];
        }

        hashValue %= totalBuckets;
        return hashValue;


    }
    void print(){

        cout << "ScopeTable # " << tableId << endl ;
        for(int i=0;i<totalBuckets;i++){
            
            if(table[i] != nullptr){
            	cout << " " <<  i << " -->" ;
                cout << table[i]->printSymbolInfoChain();
            	cout << endl ;
            }
        }
        cout << endl;
        return ;
    }

    ~scopeTable(){

        for(int i=0;i<totalBuckets;i++){
            if(table[i] != nullptr) delete table[i];
        }
        delete [] table;
        parentScope = nullptr;

        
    }

};

