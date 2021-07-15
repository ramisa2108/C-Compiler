#include <string>
using namespace std;
class symbolInfo{

     string name;
     string type;
     symbolInfo *nextSymbolInfo;
public:

    symbolInfo(string n, string t){

        name = n;
        type = t;
        nextSymbolInfo = nullptr;

    }
    void setName(string n){
        name = n;
    }

    void setType(string t){
        type = t;
    }

    void setNextSymbolInfo(symbolInfo *nxt){
        nextSymbolInfo = nxt;
    }

    string getName(){
        return name;
    }

    string getType(){
        return type;
    }

    symbolInfo *getNextSymbolInfo(){
        return nextSymbolInfo;
    }

    symbolInfo *searchSymbol(string name, int &position){

        symbolInfo *now = this;
        while(now != nullptr){

            if(now->name == name){
                break;
            }
            now = now->nextSymbolInfo;
            position++;
        }
        return now;
    }

    symbolInfo *findParent(string name){

        symbolInfo *parent = nullptr;
        symbolInfo *now = this;

        while(now != nullptr){

            if(now->name == name) return parent;
            parent = now;
            now = now->nextSymbolInfo;
        }
        return parent;
    }

    int extendChain(string name, string type){

        symbolInfo *now = this;
        int pos = 1;
        while(now != nullptr){

            if(now->name == name) return -1;
            else if(now->nextSymbolInfo == nullptr)
            {
                now->nextSymbolInfo = new symbolInfo(name, type);
                return pos;
            }
            now = now->nextSymbolInfo;
            pos++;
        }
        return -1;

    }
    string symbolInfoToString(){
        return " < " + name + " : " + type + " > ";
    }
    string printSymbolInfoChain(){

        string printChain = " ";
        symbolInfo *now = this;

        while(now != nullptr){

            printChain += now->symbolInfoToString();
            now = now->nextSymbolInfo;
        }
        return printChain;

    }
    ~symbolInfo(){

        if(nextSymbolInfo != nullptr) delete nextSymbolInfo;

    }
};

