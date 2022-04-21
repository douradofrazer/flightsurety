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


    uint256 public constant INSURANCE_PRICE_LIMIT = 1 ether;
    uint256 public constant MINIMUM_FUNDS = 10 ether;

    //multiparty variables
    uint8 private constant MULTIPARTY_CONSENSUS_MIN= 4;
    uint256 public airlinesCount = 0;

    struct Airline {
        string name;
        address account;
        bool isRegistered;
        uint256 funded;
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
    }

    mapping(bytes32 => Flight) private flights;

    struct Insurance {
        bytes32 flightCode;
        uint256 amount;
    }

    mapping(address => Insurance []) private passengerInsurance;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
     event AirlineRegistrationQueued(string name, address addr, uint256 votes);
     event AirlineRegistered(string name, address addr);
     event ContractAuthorized(address addr);
     event InsurancePurchased(address airline, string flight, uint256 amount);


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
                                        funded: 0,
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


    /**
    * @dev Check if the address is a registered airline
    *
    * @return A bool confirming whether or not the address is a registered airline
    */
    function isAirline(address airline) external view returns(bool) {
        return airlines[airline].isRegistered;
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
    {
        require(airlineAddress != address(0), "'airline' must be a valid address.");
        require(!airlines[airlineAddress].isRegistered, "Airline is already registered.");

        //Only existing airline may register a new airline until there are at least four airlines registered
        if(airlinesCount < MULTIPARTY_CONSENSUS_MIN){
            airlines[airlineAddress] = Airline({
                                            name: airlineName,
                                            account: airlineAddress,
                                            isRegistered: false,
                                            funded: 0,
                                            voted: 0
                                        });
            airlinesCount++;
        } else {
            queueAirlineRegistration(airlineAddress, airlineName);
        }
    }

    function queueAirlineRegistration (address airlineAddress, string memory airlineName) internal requireIsOperational {
        
        // check if the voter already casted his vote, if not proceed to add the vote
        airlines[airlineAddress].voted++;

        if (airlines[airlineAddress].voted >= airlinesCount.div(2)) {
            airlines[airlineAddress].name = airlineName;
            airlines[airlineAddress].account = airlineAddress;
            airlines[airlineAddress].isRegistered = false;
            airlines[airlineAddress].funded = 0;
            airlinesCount++;

            emit AirlineRegistered(airlineName, airlineAddress);
            
        } else {

            emit AirlineRegistrationQueued(airlineName, airlineAddress, airlines[airlineAddress].voted);

        }
    }


   /**
    * @dev Buy insurance for a flight
    * Ref : https://programtheblockchain.com/posts/2017/12/15/writing-a-contract-that-handles-ether/
    */   
    function buy(address airline, string memory flight, uint256 timestamp) external payable
    requireIsOperational
    requireAuthorizedContract 
    {
        require(msg.sender == tx.origin, 'Contracts not allowed.');
        require(msg.value > 0 , 'You need to pay a minium to purchase a flight insurance.');

        bytes32 flightCode = getFlightKey(airline, flight, timestamp);

        uint256 amount = msg.value;
        passengerInsurance[msg.sender].push(Insurance(flightCode, amount));

        emit InsurancePurchased(airline, flight, amount);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees() external pure
    {

    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay() external pure
    {

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

