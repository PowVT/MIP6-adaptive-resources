pragma solidity >=0.6.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";

contract BeneficiaryStream {

    
    //using EnumerableSet for EnumerableSet.AddressSet;

    address[] approvedBeneficiaries;
    address payable public adaptiveAddress = payable(0x9E67029403675Ee18777Ed38F9C1C5c75F7B34f2); // Adaptive (Evan) Metamask.

    mapping (address => uint256) private _payoutTotals;   // The beneficiaries address and how much they are approved for.

    event Withdraw( address indexed to, uint256 amount );
    event Deposit( address indexed from, uint256 amount );
    
    constructor() {
        //UNICEF, MUMA, DevSol    
        approvedBeneficiaries = [ 0x7Fd8898fBf22Ba18A50c0Cb2F8394a15A182a07d, 0xF08E19B6f75686f48189601Ac138032EBBd997f2, 0x93eb95075A8c49ef1BF3edb56D0E0fac7E3c72ac];
    }

    //-----------------------------------------Beneficiary-Allowance----------------------------------------------------
    // Internal
    function increasePayout(address recipient, uint256 addedValue) internal returns (bool) {
        uint256 currentBalance = 0;
        if(_payoutTotals[recipient] != 0) {
            currentBalance = _payoutTotals[recipient];
        }
        _payoutTotals[recipient] = addedValue + currentBalance;
        return true;
    }

    // Internal
    function decreasePayout(address beneficiary, uint256 subtractedValue) internal returns (bool) {
        uint256 currentAllowance = _payoutTotals[beneficiary];
        require(currentAllowance >= subtractedValue, "ERC20: decreased payout below zero");
        uint256 newAllowance = currentAllowance - subtractedValue;
        _payoutTotals[beneficiary] = newAllowance;
        return true;
    }

    // Public
    function payout(address recipient) public view returns (uint256) {
        return _payoutTotals[recipient];
    }

    //-------------------------------------------Vendor-Functions-----------------------------------------------------

    // A beneficiary calls function and if address is approved, beneficiary recieves xDai in return.
    function getPayout(address payable addressOfBeneficiary) public returns (string memory, uint256) {
        require(msg.sender == addressOfBeneficiary, "You must be the beneficiary to recieve their funds!");
        
        uint256 allowanceAvailable = _payoutTotals[addressOfBeneficiary];

        if (allowanceAvailable != 0 && allowanceAvailable > 0) {
            addressOfBeneficiary.transfer(allowanceAvailable);
            decreasePayout(addressOfBeneficiary, allowanceAvailable);
            console.log("transfer success");
            emit Withdraw(addressOfBeneficiary, allowanceAvailable);
        }
        else{
            console.log("Address does not have an available payout.");
            return("Address does not have an available payout.", allowanceAvailable);
        }

    }

    function streamDeposit() public payable {
      emit Deposit( msg.sender, msg.value );
    }
    
    function streamWithdraw(uint amount) public {
        require(msg.sender == 0x9E67029403675Ee18777Ed38F9C1C5c75F7B34f2, "Only the Adaptive team can collect leftover stream balances.");
        uint256 balance = streamBalance();
        require(balance > 0, "There are not enough funds in the contract to fullfill request.");
        adaptiveAddress.transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    function streamBalance() public view returns(uint256){
        uint256 balance = address(this).balance;
        return balance;
    }

    receive() external payable { 
        streamDeposit();
    }

}