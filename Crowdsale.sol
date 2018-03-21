pragma solidity ^0.4.20;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./ERC20Interface.sol";

/**
* @title Crowdsale
* @dev Crowdsale is a base contract for managing a token crowdsale,
* allowing investors to purchase tokens with ether. This contract implements
* such functionality in its most fundamental form and can be extended to provide additional
* functionality and/or custom behavior.
* The external interface represents the basic interface for purchasing tokens, and conform
* the base architecture for crowdsales. They are *not* intended to be modified / overriden.
* The internal interface conforms the extensible and modifiable surface of crowdsales. Override
* the methods to add functionality. Consider using 'super' where appropiate to concatenate
* behavior.
*/

contract Crowdsale is Ownable {
    using SafeMath for uint256;


    // The token being sold
    ERC20Interface public token;

    // Address where funds are collected
    address public wallet;

    //maximum and minimum investment limit per individual value in wei
    uint256 public minAmount = 200000000000000000;//0.2 ether
    uint256 public maxAmount = 1000000000000000000;//testvalue max of 1 ether//20000000000000000000;//20 ether

    // How many token units a buyer gets per wei at each stage of the crowdsale
    uint256 public rate;
    uint256 public rate1;
    uint256 public rate2;
    uint256 public rate3;
    uint256 public rate4;
    uint256 public rate5;

    //amount of tokens in each stage
    //tokens distribution
    uint256 public stage2Threshold = 1000000 * 10 ** 18;
    uint256 public stage3Threshold = 3000000 * 10 ** 18;
    uint256 public stage4Threshold = 6000000 * 10 ** 18;
    uint256 public stage5Threshold = 8000000 * 10 ** 18;

    // Amount of wei raised
    uint256 public weiRaised;

    //amount of tokens sold
    uint256 public tokensSold = 0;

    //current stage of crowdsale
    enum StageLevel {ONE, TWO, THREE, FOUR, FIVE, END}
    StageLevel public stageLevel;

    /**
    * Event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param beneficiary who got the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    /**
    * @param _rate Number of token units a buyer gets per wei
    * @param _wallet Address where collected funds will be forwarded to
    * @param _token Address of the token being sold
    */
    function Crowdsale(uint256 _rate, address _wallet, ERC20Interface _token) public payable {
        require(_rate > 0);
        require(_wallet != address(0));
        require(_token != address(0));

        rate1 = _rate;
        rate2 = _rate.div(10);
        rate3 = _rate.div(100);
        rate4 = _rate.div(200);
        rate5 = _rate.div(300);

        stageLevel = StageLevel.ONE;
        rate = rate1;

        wallet = _wallet;
        token = _token;
    }

    // -----------------------------------------
    // Crowdsale external interface
    // -----------------------------------------

    /**
    * @dev fallback function ***DO NOT OVERRIDE***
    */
    function () external payable {
        buyTokens(msg.sender);
    }

    /**
    * @dev low level token purchase ***DO NOT OVERRIDE***
    * @param _beneficiary Address performing the token purchase
    */
    function buyTokens(address _beneficiary) public payable {

        uint256 weiAmount = msg.value;
        _preValidatePurchase(_beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        // update state
        weiRaised = weiRaised.add(weiAmount);

        _processPurchase(_beneficiary, tokens);
        TokenPurchase(msg.sender, _beneficiary, weiAmount, tokens);

        _updatePurchasingState(_beneficiary, weiAmount);

        _forwardFunds();
        _postValidatePurchase(_beneficiary, weiAmount);

        _updateCrowdsaleStage();
    }

    //owner can end crowdsale and send remaining tokens to whomever he wants
    function endCrowdsale( address _returnAddress, uint256 _tokenAmount) public onlyOwner {
        stageLevel = StageLevel.END;
        _deliverTokens(_returnAddress, _tokenAmount);
    }

    // -----------------------------------------
    // Internal interface (extensible)
    // -----------------------------------------

    /**
    * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
    * @param _beneficiary Address performing the token purchase
    * @param _weiAmount Value in wei involved in the purchase
    */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
        require(_beneficiary != address(0));
        require(_weiAmount >= minAmount);
        require(_weiAmount <= maxAmount);
    }

    /**
    * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid conditions are not met.
    * @param _beneficiary Address performing the token purchase
    * @param _weiAmount Value in wei involved in the purchase
    */
    function _postValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
        // optional override
    }

    /**
    * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
    * @param _beneficiary Address performing the token purchase
    * @param _tokenAmount Number of tokens to be emitted
    */
    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
        token.transfer(_beneficiary, _tokenAmount);
    }

    /**
    * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
    * @param _beneficiary Address receiving the tokens
    * @param _tokenAmount Number of tokens to be purchased
    */
    function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
        _deliverTokens(_beneficiary, _tokenAmount);
    }

    /**
    * @dev Override for extensions that require an internal state to check for validity (current user contributions, etc.)
    * @param _beneficiary Address receiving the tokens
    * @param _weiAmount Value in wei involved in the purchase
    */
    function _updatePurchasingState(address _beneficiary, uint256 _weiAmount) internal {
        // optional override
    }

    function _updateCrowdsaleStage() internal {
        if (tokensSold > stage5Threshold) {
            stageLevel = StageLevel.FIVE;
            rate = rate5;
        } else if (tokensSold > stage4Threshold) {
            stageLevel = StageLevel.FOUR;
            rate = rate4;
        } else if (tokensSold > stage3Threshold) {
            stageLevel = StageLevel.THREE;
            rate = rate3;
        } else if (tokensSold > stage2Threshold) {
            stageLevel = StageLevel.TWO;
            rate = rate2;
        }
    }

    /**
    * @dev Override to extend the way in which ether is converted to tokens.
    * @param _weiAmount Value in wei to be converted into tokens
    * @return Number of tokens that can be purchased with the specified _weiAmount
    */
    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
        return _weiAmount.mul(rate);
    }

    /**
    * @dev Determines how ETH is stored/forwarded on purchases.
    */
    function _forwardFunds() internal {
        wallet.transfer(msg.value);
    }

}
