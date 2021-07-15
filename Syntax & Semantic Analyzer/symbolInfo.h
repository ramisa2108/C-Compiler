#include <string>
using namespace std;

class functionProperties{

public:
    vector<string>parameters;
    bool defined;

    functionProperties()
    {
        defined = false;
    }
    void setDefined(bool d=true)
    {
        defined = d;
    }
    void addParameter(string param)
    {
        parameters.push_back(param);
    }
    int getCount()
    {
        return parameters.size();
    }
    string getMismatch(functionProperties *fp)
    {
        for(int i=0;i<parameters.size();i++)
        {
            if(parameters[i] != fp->parameters[i]) 
            	return to_string(i+1) + "th argument mismatch in function ";
        }
        return "";
        	
    }
    
    

};

class symbolInfo{

public:

	string name;
	string type;
	string typeSpecifier;
	symbolInfo *nextSymbolInfo;
	int size;
	functionProperties *funcProp;
	
	
    symbolInfo(){

        name = "";
        type = "";
        typeSpecifier="";
        nextSymbolInfo = nullptr;
        funcProp = nullptr;
        size = 0;
    }
    
    symbolInfo(symbolInfo &s)
    {
        name = s.name;
        type = s.type;
        typeSpecifier = s.typeSpecifier;
        nextSymbolInfo = s.nextSymbolInfo;
        funcProp = s.funcProp;
        size = s.size;
        

    }
    symbolInfo(string n, string t="", string ts="",int sz=0){

        name = n;
        type = t;
        typeSpecifier = ts;
        nextSymbolInfo = nullptr;
        funcProp = nullptr;
        size = sz;
        
        

    }
    void setName(string n){
        name = n;
    }

    void setType(string t){
        type = t;
    }
    void setTypeSpecifier(string ts)
    {
    	typeSpecifier = ts;
    }
    void setNextSymbolInfo(symbolInfo *nxt){
        nextSymbolInfo = nxt;
    }
    void setSize(int sz){
    	size = sz;
    }
    
    void setFuncProp(){
    
    	funcProp = new functionProperties();
    	
    }
    symbolInfo *getNextSymbolInfo(){
    	return nextSymbolInfo;
    }
    
    
    void addParameter(string paramType)
    {
    	if(funcProp == nullptr)
    	{
    		funcProp = new functionProperties();
    	}
    	funcProp->addParameter(paramType);
    	return ;
    }

    void functionDefined()
    {
        if(funcProp == nullptr) funcProp = new functionProperties();
        funcProp->setDefined(true);
        
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

    int extendChain(symbolInfo &s){

        symbolInfo *now = this;
        int pos = 1;
        while(now != nullptr){

            if(now->name == s.name) return -1;
            else if(now->nextSymbolInfo == nullptr)
            {
                now->nextSymbolInfo = new symbolInfo(s);
                return pos;
            }
            now = now->nextSymbolInfo;
            pos++;
        }
        return -1;

    }
    
    string printSymbolInfoChain(){

        string printChain = " ";
        symbolInfo *now = this;

        while(now != nullptr){
        
        	if(type == "") printChain += "< " + now->name + " > ";
        	else printChain += "< " + now->name + " , " + now->type + " > ";
        	now = now->nextSymbolInfo;
            
        }
        return printChain;

    }
    void ToString(){
    	cout <<  name;
    }
    ~symbolInfo(){
        if(nextSymbolInfo != nullptr) delete nextSymbolInfo;

    }


};

class nonTerminal : public symbolInfo{

public:

	
	nonTerminal *sibling;
	nonTerminal *child;
	
	
    nonTerminal() : symbolInfo(){

        sibling = nullptr;
        child = nullptr;
        
    }
    
    nonTerminal(symbolInfo *si): symbolInfo(si->name, si->type, si->typeSpecifier, si->size){
    	
    	
        sibling = nullptr;
        child = nullptr;
        

    }
    
    nonTerminal(nonTerminal &n) : symbolInfo(n.name, n.type, n.typeSpecifier, n.size)
    {
        
        sibling = n.sibling;
        child = n.child;
        

    }
    nonTerminal(string n, string t="", string ts="",int sz=0): symbolInfo(n,t,ts,sz){

        
        sibling = nullptr;
        child = nullptr;
        

    }
    
    void addNextChild(nonTerminal *nt)
    {
    	if(child == nullptr){
    		child = nt;
    	}
    	else 
    	{
    		nonTerminal *now = child;
    		while(now->sibling != nullptr)
    		{
    			now = now->sibling;
    		}
    		now->sibling = nt;
    	}
    }
    void addNextChild(symbolInfo *si)
    {
    	addNextChild(new nonTerminal(si));
    }
    
    string getName(){
    	nonTerminal *now = this;
    	while(now->child != nullptr){
    		now = now->child;
    	}
    	return now->name;
    }
    
    
    string getTerminals(){
    	
    	string terminals = "";
    	if(child != nullptr) terminals += child->getTerminals();
    	else terminals += name;
    	
    	if(sibling != nullptr) terminals += sibling->getTerminals();
    	return terminals;
    }
    
    
    void ToString(){
    	
    	if(child != nullptr) child->ToString();
    	else cout << name ;
	if(type == "TYPE_SPECIFIER" || type == "KEYWORD" || name == "return") cout << ' ';
	if(name == ";" || name=="{" || name=="}") cout << endl;
	if(sibling != nullptr) sibling->ToString();
	
    }
    
    ~nonTerminal(){
        
        if(child != nullptr) delete child;
        delete sibling;
        

    }
};

