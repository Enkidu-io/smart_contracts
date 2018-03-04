
pragma solidity ^0.4.10;
import './ENKToken.sol';
import './Pausable.sol';
import './BTC.sol';
import './Utils.sol';
import './SafeMath.sol';
import './PricingStrategy.sol';
import './Ownable.sol';
import './Sales.sol';

contract TokenSale is Ownable,Pausable, Utils,Sales{

    ENKToken token;
    uint256 public initialSupplyPreSale;
    uint256 public initialSupplyPublicSale;
    PricingStrategy pricingstrategy;
    uint256 public tokenCreationMax = 15*(10**5) * (10**18);
    ///token creation max for the pre ico state
    ///token creation max for the public sale

    ///tokens for bonus
    uint256 public bonus = 25 * (10**6) * (10**18);
    ///team
    uint256 public team = 35 * (10**6) * (10**18);
    ///tokens for reserve
    uint256 public affiliate = 40 * (10**6) * (10**18);
    ///tokens for the mentors
    uint256 public advisors = 30 * (10**6) * (10**18);
    ///tokkens for the bounty
    uint256 public bounty = 20*(10**6) * (10**18);

    ///address for the teeam,investores,etc
    address public addressbonus = "";
    
    address public addressteam = "";

    address public addressaffiliate = "";

    address public addressVestedAdvisors = "";

    address public addressbounty = "";

    ///array of addresses for the ethereum relateed back funding  contract
    uint256  public numberOfBackers;
    /* Max investment count when we are still allowed to change the multisig address */
    ///the txorigin is the web3.eth.coinbase account
    //record Transactions that have claimed ether to prevent the replay attacks
    //to-do
    mapping(uint256 => bool) transactionsClaimed;
    uint256 public valueToBeSent;
    uint public investorCount;

    ////thr owner address
    address public ownerAddr = "";

    ///the event log to log out the address of the multisig wallet
    event logaddr(address addr);

    //the constructor function
   function TokenSale(address tokenAddress,address strategy){
        //require(bytes(_name).length > 0 && bytes(_symbol).length > 0); // validate input
        token = ENKToken(tokenAddress);
        valueToBeSent = token.valueToBeSent();
        pricingstrategy = PricingStrategy(strategy);
    }

    /**
        Payable function to send the ether funds
    **/
    function() external payable stopInEmergency{
        ///This is the main payable function
        ///get the current state of the ico
        bool  isValid = token.isValid();
        if(!isValid) throw;
        ICOSaleState currentState = getStateFunding();
        if(currentState==ICOSaleState.Failed) throw;
        if (msg.value == 0) throw;
        var (discount,usd,tokens) = pricingstrategy.totalDiscount(currentState,msg.value,"ethereum",initialSupplyPublicSale);
        uint256 totalTokens = SafeMath.add(tokens,SafeMath.div(SafeMath.mul(tokens,discount),100));
        if(currentState==ICOSaleState.PreSale){
            require(SafeMath.add(initialSupplyPreSale,totalTokens)<token.tokenCreationMaxPreSale());
            initialSupplyPreSale = SafeMath.add(initialSupplyPreSale,totalTokens);
        }else{
            require(SafeMath.add(initialSupplyPublicSale,totalTokens)<token.tokenCreationMaxPublicSale());
            initialSupplyPublicSale = SafeMath.add(initialSupplyPublicSale,totalTokens);
        }
        tokenCreationMax = SafeMath.sub(tokenCreationMax,totalTokens);
        token.addToBalances(msg.sender,totalTokens);
        token.increaseEthRaised(msg.value);
        numberOfBackers++;
        token.increaseUSDRaised(usd);
        if(!ownerAddr.send(this.balance))throw;
    }



    //Token distribution for the case of the ICO
    ///function to run when the transaction has been veified
    function processTransaction(bytes txn, uint256 txHash,address addr,bytes20 btcaddr) onlyOwner returns (uint)
    {
        bool  valueSent;
        bool  isValid = token.isValid();
        if(!isValid) throw;
     ICOSaleState currentState = getStateFunding();

        if(!transactionsClaimed[txHash]){
            var (a,b) = BTC.checkValueSent(txn,btcaddr,valueToBeSent);
            if(a){
                valueSent = true;
                transactionsClaimed[txHash] = true;
                 ///since we are creating tokens we need to increase the total supply
               allottTokensBTC(addr,b,currentState);
        return 1;
        }
            }

    }
    
    ///function to allot tokens to address
    function allottTokensBTC(address addr,uint256 value,ICOSaleState state) internal{
        ICOSaleState currentState = getStateFunding();
        if(currentState==ICOSaleState.Failed) throw;
        var (discount,usd,tokens) = pricingstrategy.totalDiscount(state,value,"bitcoin",initialSupplyPublicSale);
        uint256 totalTokens = SafeMath.add(tokens,SafeMath.div(SafeMath.mul(tokens,discount),100));
        if(currentState==ICOSaleState.PreSale){
            require(SafeMath.add(initialSupplyPreSale,totalTokens)<token.tokenCreationMaxPreSale());
            initialSupplyPreSale = SafeMath.add(initialSupplyPreSale,totalTokens);
        }else{
            require(SafeMath.add(initialSupplyPublicSale,totalTokens)<token.tokenCreationMaxPublicSale());
            initialSupplyPublicSale = SafeMath.add(initialSupplyPublicSale,totalTokens);
        }        
        tokenCreationMax = SafeMath.sub(tokenCreationMax,totalTokens);
        token.addToBalances(addr,totalTokens);
        numberOfBackers++;
        token.increaseBTCRaised(value);
        token.increaseUSDRaised(usd);
    }

    function finalizeTokenSale() public onlyOwner{
        ICOSaleState currentState = getStateFunding();
        if(currentState!=ICOSaleState.Success) throw;
        token.addToVesting(addressbonus,bonus);
        token.addToBalances(addressteam,team);
        token.addToBalances(addressaffiliate,affiliate);
        token.addToVesting(addressVestedAdvisors,advisors);
        token.addToVesting(addressbounty,bounty);
        token.finalizeICO();
    }

    function getStateFunding() returns (ICOSaleState){
       if(now>token.fundingStartBlock() && now<=token.presaleEndBlock()) return ICOSaleState.PreSale;
       if(now>token.presaleEndBlock() && now<=token.fundingEndBlock()) return ICOSaleState.PublicSale;
       if(now>token.fundingEndBlock() && token.usdraised()<token.minCapUSD()) return ICOSaleState.Failed;
       if(now>token.fundingEndBlock() && token.usdraised()>=token.minCapUSD()) return ICOSaleState.Success;
    }

    

}