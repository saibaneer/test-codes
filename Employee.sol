//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.1;


contract JobReq {
    //Define the state of the job
    enum JobState {Uninitiated ,Pending, Reviewing, ApprovedByUser, ApprovedByOwner}
    JobState state;
    
    //Check if the job is completed
    bool isComplete = false;
    
    //Mapping for storing jobs and job id
    mapping(address => uint) senderAddress;
    
    //Mapping for Agents accepting Jobs
    mapping(uint => address) agentAddress;
    
    //Holder of JobID which is a key identifier in this smart contract
    uint public jobID = 0;
    
    //Array for holding each address which initiates a job
    address[] public addressId;
    
    //The variable holds the address of admin
    address public adminAddress;

    
    
    constructor() {
        //Hardcode the address for admin.
        adminAddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    }
    
    modifier onlyJobOwner(uint _jobID){
        require(msg.sender == jobs[_jobID]._createdBy, "You are not authorized!");        
        _;
    }
    
    modifier onlyAgent(uint _jobID){
        require(msg.sender == agentAddress[_jobID], "You are not the Agent assigned to this task!");        
        _;
    }    
    
    //Created this datatype to store job owners and the amount sent into the contract for reconciliation purposes
    struct adminRecord {
        address _sentBy;
        uint _amount;
    }

    
    //define the mapping for records
    mapping(uint =>  adminRecord) public records;

    //created this datatype to store information elements of the job creator
    struct Job {
        string _task;
        uint _amount;
        bool _completed;
        JobState _state;
        address _createdBy;
    }
    
    //a mapping association using the jobID as key to retrieve the job info in the struct above
    mapping(uint => Job) public jobs;
    
    //the function will add a new job 
    function addJob(string memory _string) public payable {
        require(bytes(_string).length > 0 && msg.value != 0, "You must add a task and send ether" );
        senderAddress[msg.sender] += msg.value;
        jobs[jobID] = Job(_string, senderAddress[msg.sender], isComplete, JobState.Uninitiated, msg.sender); 
        addressId.push(msg.sender);
        jobID++;
    }
    
    //although not needed the function will return the job info based on jobID
    function getJob(uint i) public view returns (address, Job memory) {
        return (addressId[i], jobs[i]);
    }
    
    //the function will move funds from the wallet owner into escrow until the job is done
    function deployJob(uint _jobID) public onlyJobOwner(_jobID){

        jobs[_jobID]._state = JobState.Pending;
        //create a trx record within the contract for easy recall
        records[_jobID]._amount = jobs[_jobID]._amount;
        jobs[_jobID]._amount = 0;
        //update address of sender
        records[_jobID]._sentBy = addressId[_jobID];
        //payable(adminAddress).transfer(balanceToSend); //could not define payable on adminAddress earlier why?
    }
    
    //This function will return funds from the admin wallet to job owner
    function refundTransaction(uint _jobID) public {
        require(msg.sender == adminAddress, "You are not authorized!");
        payable(records[_jobID]._sentBy).transfer(records[_jobID]._amount);
        jobs[_jobID]._state = JobState.Uninitiated;
    }
    
    //this function will allow the user accept a job
    function acceptJob(uint _jobID) public {
        require(msg.sender != jobs[_jobID]._createdBy, "You can't accept a Job you created!");    
        require(jobs[_jobID]._state == JobState.Pending, "This job is yet to be deployed");
        jobs[_jobID]._state = JobState.Reviewing;
        agentAddress[_jobID] = msg.sender;
        
    }
    
    //this function allows the user to signify that the job is complete, 
    // it should emit a notification to the blockchain
    function userJobComplete(uint _jobID) public onlyAgent(_jobID) {

        require(jobs[_jobID]._state == JobState.Reviewing, "This job is yet to be Reviewed");
        jobs[_jobID]._state = JobState.ApprovedByUser;
    }
    //this function allows the owner validate that the job is done
    function ownerJobComplete(uint _jobID) public onlyJobOwner(_jobID) {
        require(jobs[_jobID]._state == JobState.ApprovedByUser, "This job is yet to be completed by Agent");
        jobs[_jobID]._state = JobState.ApprovedByOwner;
        jobs[_jobID]._completed = true;
        payAgent(_jobID);
        
    }
    //this is an internal function 
    function payAgent(uint _jobID) internal {
        require(jobs[_jobID]._completed == true);
        payable(agentAddress[_jobID]).transfer(records[_jobID]._amount);        
    }
    
    function rejectCompletion(uint _jobID) public {
        require(jobs[_jobID]._state == JobState.ApprovedByUser, "This job is yet to be completed by Agent");
        jobs[_jobID]._state = JobState.Reviewing;
    }
    
    function abandonTask(uint _jobID) public onlyAgent(_jobID) {
        payable(records[_jobID]._sentBy).transfer(records[_jobID]._amount);
        jobs[_jobID]._state = JobState.Uninitiated; 
        delete agentAddress[_jobID];
    }
    
    function withdrawFromWallet(uint _jobID) public onlyJobOwner(_jobID) {
        if (jobs[_jobID]._state == JobState.Pending){
            payable(records[_jobID]._sentBy).transfer(records[_jobID]._amount);
        }
        else if (jobs[_jobID]._state == JobState.Uninitiated) {
            payable(jobs[_jobID]._createdBy).transfer(jobs[_jobID]._amount);
        }

        delete jobs[_jobID];
        delete records[_jobID];
    }
}