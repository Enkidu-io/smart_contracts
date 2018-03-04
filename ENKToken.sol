pragma solidity ^0.4.10;

import './SafeMath.sol';
import './Ownable.sol';
import './Pausable.sol';
import './Sales.sol';


contract Token {
    uint256 public totalSupply;
    function balanceOf(address _owner) constant returns (uint256 balance);
    function transfer(address _to, uint256 _value) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);
    function approve(address _spender, uint256 _value) returns (bool success);
    function allowance(address _owner, address _spender) constant returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}


/*  ERC 20 token */
contract ENKToken is Token,Ownable,Sales {
    string public constant name = "Enkidu Token";
    string public constant symbol = "ENK";
    uint256 public constant decimals = 18;
    string public version = "1.0";

    ///The value to be sent to our BTC address
    uint public valueToBeSent = 1;
    ///The ethereum address of the person manking the transaction
    address personMakingTx;
    //uint private output1,output2,output3,output4;
    ///to return the address just for the testing purposes
    address public addr1;
    ///to return the tx origin just for the testing purposes
    address public txorigin;

    //function for testing only btc address
    bool isTesting;
    ///testing the name remove while deploying
    bytes32 testname;
    address finalOwner;
    bool public finalizedICO = false;

    uint256 public ethraised;
    uint256 public btcraised;
    uint256 public usdraised;

    bool public istransferAllowed;

    uint256 public constant ENKFund = 25 * (10**7) * 10**decimals; 
    ///All the below times are in UNIX Timeestamps
    ///These Values have to be changed
    uint256 public fundingStartBlock = 1519644668; 
    uint256 public fundingEndBlock = 1523664000; 
    uint256 public presaleEndBlock = 1523464000;
    uint256 tokenVestingTime = 15552000;///6 months
    uint256 public tokenCreationMax= 10 * (10**7) * 10**decimals; //TODO

    uint256 public tokenCreationMaxPreSale = 5 * (10**7) * 10**decimals;
    uint256 public tokenCreationMaxPublicSale = 5 * (10**7) * 10**decimals;

    ///ownership
    mapping (address => bool) ownership;
    uint256 public minCapUSD = 2000000;
    uint256 public maxCapUSD = 18000000;


    mapping (address => uint256) balances;
    mapping (address => VestingBalance) public vestingBalanceOf;

    ///the struct for the vesting balance
    struct VestingBalance{
        uint256 totalBalance;
        mapping(uint256 => uint256) dates;
    }

    ////allowed struct
    mapping (address => mapping (address => uint256)) allowed;

    modifier onlyPayloadSize(uint size) {
        require(msg.data.length >= size + 4);
        _;
    }

    function transfer(address _to, uint256 _value) onlyPayloadSize(2 * 32) returns (bool success) {
      checkMyVesting(msg.sender);
      if(!istransferAllowed) throw;
      if (balances[msg.sender] >= _value && _value > 0) {
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;
      } else {
        return false;
      }
    }

    //this is the default constructor
    function ENKToken(){
        totalSupply = ENKFund;
    }

    event PublicSaleEndChanged(uint256 _newEndBlock);
    ///change the funding end block
    function changeEndBlock(uint256 _newFundingEndBlock) onlyOwner{
        fundingEndBlock = _newFundingEndBlock;
        PublicSaleEndChanged(_newFundingEndBlock);
    }


    event PreSaleEndChanged(uint256 _preSaleNewEnd);
    ///change the pre sale end timmestamp
    function changePreSaleEnd(uint256 _newPresaleEndBlock) onlyOwner{
        presaleEndBlock = _newPresaleEndBlock;
        PreSaleEndChanged(_newPresaleEndBlock);
    }

    ///the Min Cap USD 
    ///function too chage the miin cap usd
    event ChangedMinCap(uint256 _newMinCap);
    function changeMinCapUSD(uint256 _newMinCap) onlyOwner{
        minCapUSD = _newMinCap;
        ChangedMinCap(_newMinCap);
    }

    event ChangedMaxCap(uint256 _newMaxCap);
    ///fucntion to change the max cap usd
    function chanegMaxCapUSD(uint256 _newMaxCap) onlyOwner{
        maxCapUSD = _newMaxCap;
        ChangedMaxCap(_newMaxCap);
    }

    ///the function to add to vesting for 6 Months
    function addToVesting(address addr,uint256 _val) external {
        require(ownership[msg.sender]);
        ////add to the vesting address
        balances[addr] = SafeMath.add(balances[addr],_val);
    }

    /***Event to be fired when the state of the sale of the ICO is changes**/
    event stateChange(ICOSaleState state);

    function transferFrom(address _from, address _to, uint256 _value) onlyPayloadSize(3 * 32) returns (bool success) {
    checkMyVesting(_from);
      if(!istransferAllowed) throw;
      if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
      } else {
        return false;
      }
    }

    ///thr function to check the vesting
    function checkMyVesting(address spender) internal{

    }

    function addToBalances(address _person,uint256 value) {
        if(!ownership[msg.sender]) throw;
        balances[_person] = SafeMath.add(balances[_person],value);

    }

    function addToOwnership(address owners) onlyOwner{
        ownership[owners] = true;
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) onlyPayloadSize(2 * 32) returns (bool success) {
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }

    function increaseEthRaised(uint256 value){
        if(!ownership[msg.sender]) throw;
        ethraised+=value;
    }

    function increaseBTCRaised(uint256 value){
        if(!ownership[msg.sender]) throw;
        btcraised+=value;
    }

    function increaseUSDRaised(uint256 value){
        if(!ownership[msg.sender]) throw;
        usdraised+=value;
    }

    function finalizeICO(){
        if(!ownership[msg.sender]) throw;
        if(usdraised<minCapUSD) throw;
        finalizedICO = true;
        istransferAllowed = true;
    }


    function isValid() returns(bool){
        if(block.number>=fundingStartBlock && block.number<fundingEndBlock ){
            return true;
        }else{
            return false;
        }
        if(usdraised>maxCapUSD) throw;
    }

    ///do not allow payments on this address

    function() payable{
        throw;
    }
}

