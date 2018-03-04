pragma solidity ^0.4.8;
import "./usingOraclize.sol";
import './Sales.sol';
import "./strings.sol";
import "./Ownable.sol";

contract PricingStrategy is usingOraclize,Ownable{
    using strings for *;
    uint public ETHUSD=990;
    uint public BTCUSD=10000;
    uint256 public exchangeRate;
    bool public called;
    ///the function that will be initiailized
    function PricingStrategy(){
    //  OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
        update(0);
    }
    
    event logstring(string s);

      /**
     * @dev Oraclize's callback for parsing/processing response which contains ETH -> USD exchange rate
     * @param myid Unique identifier of corresponding request
     * @param result Response payload excerpt
     * @param proof TLSNotary proof
     */ 
    function __callback(bytes32 myid, string result, bytes proof) {
        require (msg.sender == oraclize_cbAddress());
        logstring(result);
        var s = result.toSlice();
        var delim = ",".toSlice();
        var parts = new string[](s.count(delim) + 1);
        for(uint i = 0; i < parts.length; i++) {
            parts[i] = s.split(delim).toString();
        }
        ETHUSD = parseInt(parts[1],1)/10; // save it in storage as $ cents
        BTCUSD = parseInt(parts[0], 0);
        update(60*60*12); // Enable recursive price updates once in every hour
    }
    
    function getLatest(uint btcusd,uint ethusd) onlyOwner{
        ETHUSD = ethusd;
        BTCUSD = btcusd;
    }


    ///log the value to get the value in usd
    event logval(uint256 s);

    /**
     * @dev Send request of getting ETH -> USD exchange rate to Oraclize
     * @param delay Delay (in seconds) when the next request will happen
     */ 
    function update(uint delay) payable {
            oraclize_query(delay, "URL", "json(https://api.kraken.com/0/public/Ticker?pair=XBTUSD,ETHUSD&result=1).result.[\"XXBTZUSD\",\"XETHZUSD\"].c.0");
    }

    ///This function will return the discount , value in usd and the total number of tokens
    function totalDiscount(Sales.ICOSaleState state,uint256 contribution,string types,uint256 crowdsaleSoldSupply) returns (uint256,uint256,uint256){
        uint256 valueInUSD;
        uint256 tokens;
        if(keccak256(types)==keccak256("ethereum")){
            if(ETHUSD==0) throw;
            valueInUSD = (ETHUSD*contribution)/1000000000000000000;
            logval(valueInUSD);

        }else if(keccak256(types)==keccak256("bitcoin")){
            if(BTCUSD==0) throw;
            valueInUSD = (BTCUSD*contribution)/100000000;
            logval(valueInUSD);

        }
        if(state==Sales.ICOSaleState.PreSale){
            tokens = valueInUSD*1000/37;
            return (40,valueInUSD,tokens);
        }
        else if(state==Sales.ICOSaleState.PublicSale){
            if(crowdsaleSoldSupply<=333*10**6){
                tokens = valueInUSD*1000/56;
                return (25,valueInUSD,tokens);
            }else if(crowdsaleSoldSupply>333*10**6 && crowdsaleSoldSupply<=138750000){
                tokens = valueInUSD*1000/56;
                return (15,valueInUSD,tokens);
            }else if(crowdsaleSoldSupply>138750000){
                tokens = valueInUSD*1000/56;
                return (10,valueInUSD,tokens);
            }
        }
        else{
            return (0,0,0);
        }
    }
    
    function() payable{
        
    }
}


///////https://ethereum.stackexchange.com/questions/11383/oracle-oraclize-it-with-truffle-and-testrpc

////https://ethereum.stackexchange.com/questions/17015/regarding-oraclize-call-in-smart-contract