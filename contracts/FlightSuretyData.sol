// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
    // Account used to deploy contract
    address private contractOwner;                                      
    // Blocks all state changes throughout the contract if false
    bool private operational = true;                                    
    // address payable public dataContractAddress;
    mapping(address => uint256) private authorizedContracts;

    uint8 private constant STATUS_UNKNOWN = 0;
    uint8 private constant STATUS_ON_TIME = 10;
    uint8 private constant STATUS_DELAYED_AIRLINE = 20;
    uint8 private constant STATUS_DELAYED_WEATHER = 30;
    uint8 private constant STATUSE_DELAYED_TECHNICAL = 40;
    uint8 private constant STATUSE_DELAYED_OTHER = 50;

    uint256 public constant INSURANCE_PRICE_LIMIT = 1 ether;
    uint256 public constant MINIMUM_FUNDS = 10 ether;

    //multiparty variables
    uint8 private constant MULTIPARTY_CONSENSUS_MIN= 4;
    uint256 public airlinesCount = 0;

    struct Airline {
        string name;
        address account;
        bool isRegistered;
        bool isFunded;
        uint8 voted;
    }

    mapping(address => Airline) private airlines;

    struct Flight {
        address airline;
        string name;
        string from;
        string to;
        uint8 status; // 0 or 1 (0 : in-flight, 1:landed)
        uint256 timestamp;
        bool isRegistered;
    }

    mapping(bytes32 => Flight) private flights;

    struct Insurance {
        bytes32 flightCode;
        uint256 amount;
        address passenger;
        uint256 multiplier;
        bool isCredited;
    }

    mapping(bytes32 => Insurance []) private passengerInsuranceByFlight;
    mapping (address => uint) public pendingPayments;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
     event AirlineRegistrationQueued(string name, address addr, uint256 votes);
     event AirlineRegistered(string name, address addr);
     event FlightRegistered(bytes32 flightKey, address airline, string flight, string from, string to, uint256 timestamp);
     event ContractAuthorized(address addr);
     event InsurancePurchased(address airline, string flight, uint256 amount, address passenger);
     event InsureeCredited(address airline, string flight);
     event AccountWithdrawn(address passenger, uint256 amount);
     event FlightStatusUpdated(address airline, string flight, uint256 timestamp, uint8 status);
     event AirlineFunded(string name, address airline);


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor(){
        contractOwner = msg.sender;
        // 	First airline is registered when contract is deployed.
        airlines[msg.sender] = Airline({    
                                        name: "FJDAirlines",
                                        account: msg.sender,
                                        isRegistered: true,
                                        isFunded: false,
                                        voted: 0
                                    });
        airlinesCount++;
        // add this as a hack to test with autoirized contract
        authorizedContracts[msg.sender] = 1;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizedContract()
    {
        require(authorizedContracts[msg.sender] == 1, "Contract is not authorized to perform the operation.");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function getBalance() public view returns(uint256)
    {
        return address(this).balance;
    }

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() public view returns(bool) 
    {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus(bool mode) external requireContractOwner 
    {
        operational = mode;
    }

    function authorizeContract(address appContract) external requireIsOperational requireContractOwner {
        authorizedContracts[appContract] = 1;
        emit ContractAuthorized(appContract);
    }

    function isFlightOnTime(address airline, string calldata flight, uint256 timestamp) external view returns(bool) {
        return flights[getFlightKey(airline, flight, timestamp)].status == STATUS_ON_TIME;
    }

    /**
    * @dev Check if the address is a registered airline
    *
    * @return A bool confirming whether or not the address is a registered airline
    */
    function isAirlineRegistered(address airline) external view returns(bool) {
        return airlines[airline].isRegistered;
    }

    function isAirlineFunded(address airline) external view returns (bool) {
        return airlines[airline].isFunded;
    }

    function isFlightRegistered(address airline, string memory flight, uint256 timestamp) external view returns (bool) {
        bytes32 flightCode = getFlightKey(airline, flight, timestamp);
        return flights[flightCode].isRegistered;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline( address airlineAddress, string memory airlineName ) 
    external 
    requireIsOperational
    requireAuthorizedContract
    returns(bool success, uint8 votes)
    {
        require(airlineAddress != address(0), "'airline' must be a valid address.");
        require(!airlines[airlineAddress].isRegistered, "Airline is already registered.");

        //Only existing airline may register a new airline until there are at least four airlines registered
        if(airlinesCount < MULTIPARTY_CONSENSUS_MIN){
            airlines[airlineAddress] = Airline({
                                            name: airlineName,
                                            account: airlineAddress,
                                            isRegistered: true,
                                            isFunded: false,
                                            voted: 0
                                        });
            airlinesCount++;
            return (true, 0);
        } else {
            return queueAirlineRegistration(airlineAddress, airlineName);
        }
    }

    // only to be used within the contract
    function queueAirlineRegistration (address airlineAddress, string memory airlineName) private returns(bool, uint8) {
        
        // check if the voter already casted his vote, if not proceed to add the vote
        airlines[airlineAddress].voted++;

        if (airlines[airlineAddress].voted >= airlinesCount.div(2)) {
            airlines[airlineAddress].name = airlineName;
            airlines[airlineAddress].account = airlineAddress;
            airlines[airlineAddress].isRegistered = true;
            airlines[airlineAddress].isFunded = false;
            airlinesCount++;

            emit AirlineRegistered(airlineName, airlineAddress);

            return (true, airlines[airlineAddress].voted);
            
        } else {

            emit AirlineRegistrationQueued(airlineName, airlineAddress, airlines[airlineAddress].voted);

            return (false, airlines[airlineAddress].voted);

        }
    }

    /**
    * @dev Submit funding for airline
    */   
    function fundAirline(address airline) external payable 
    requireIsOperational 
    requireAuthorizedContract 
    {
        require(msg.value == 10 ether, 'A funding of 10 ether is required.');
        airlines[airline].isFunded = true;
        emit AirlineFunded(airlines[airline].name, airline);
    }


    /**
    * @dev Register a flight
    */   
    function registerFlight(address airline, string memory flight, uint256 timestamp, string memory from, string memory to) external 
    requireIsOperational
    requireAuthorizedContract
    {
        bytes32 flightCode = getFlightKey(airline, flight, timestamp);

        require(!flights[flightCode].isRegistered, 'Flight has already been registered.');

        flights[flightCode] = Flight({
            airline: airline,
            name : flight,
            from : from, 
            to : to,
            status : STATUS_UNKNOWN,
            timestamp : timestamp,
            isRegistered: true
        });

        emit FlightRegistered(flightCode, airline, flight, from, to, timestamp);
    }


   /**
    * @dev Buy insurance for a flight
    * Ref : https://programtheblockchain.com/posts/2017/12/15/writing-a-contract-that-handles-ether/
    */   
    function buy(address airline, string memory flight, uint256 timestamp) external payable
    requireIsOperational 
    {
        require(msg.sender == tx.origin, 'Contracts not allowed.');
        require(msg.value > 0 , 'You need to pay a minium to purchase a flight insurance.');
        require(msg.value <= INSURANCE_PRICE_LIMIT, 'You only pay a max of 1 ether for flight insurance.');

        bytes32 flightCode = getFlightKey(airline, flight, timestamp);

        uint256 multiplier = uint(3).div(2);

        uint256 amount = msg.value;
        passengerInsuranceByFlight[flightCode].push(Insurance({
            flightCode: flightCode, 
            amount: amount, 
            passenger: msg.sender,
            multiplier: multiplier,
            isCredited: false
            }));

        emit InsurancePurchased(airline, flight, amount, msg.sender);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address airline, string memory flight, uint256 timestamp) internal
    requireIsOperational
    requireAuthorizedContract 
    {

     bytes32 flightCode = getFlightKey(airline, flight, timestamp);   

    // using a for loop here on the assumption that this list is likely going to be a small one
    for (uint i = 0; i < passengerInsuranceByFlight[flightCode].length; i++) {
      Insurance memory insurance = passengerInsuranceByFlight[flightCode][i];

      if (insurance.isCredited == false) {
        insurance.isCredited = true;
        uint256 amount = insurance.amount.mul(insurance.multiplier).div(100);
        pendingPayments[insurance.passenger] += amount;
      }
    }

    emit InsureeCredited(airline, flight);
    }


    /**
     *  @dev process flight status
    */
    function processFlightStatus(address airline, string calldata flight, uint256 timestamp, uint8 status) external
    requireIsOperational 
    requireAuthorizedContract 
    {

    bytes32 flightKey = getFlightKey(airline, flight, timestamp);    
    
    if (flights[flightKey].status == STATUS_UNKNOWN) {
      flights[flightKey].status = status;
      if(status == STATUS_DELAYED_AIRLINE) {
        creditInsurees(airline, flight, timestamp);
      }
    }

    emit FlightStatusUpdated(airline, flight, timestamp, status);
    }

    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address passenger) external 
    requireIsOperational
    {
    require(pendingPayments[passenger] > 0, "No fund available for withdrawal");

    // Effects
    uint256 amount = pendingPayments[passenger];

    require(address(this).balance > amount, "The contract does not have enough funds to pay the credit");

    pendingPayments[passenger] = 0;

    payable(passenger).transfer(amount);

    emit AccountWithdrawn(passenger, amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund() public payable
    {

    }

    function getFlightKey(address airline, string memory flight, uint256 timestamp) pure internal returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    fallback () external payable 
    {
        fund();
    }


}

