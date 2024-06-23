// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

//dt = 0xfAF646893C6D3Ef849FadD67FC1Ca3e347f409B7
//tt = 0xBF77293F2166B6Dd5292325Dd76D0d0fC14996F0
//complianceMembers = ["0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB","0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678","0x617F2E2fD72FD9D5503197092aC168c91465E7f2","0x17F6AD8Ef982297579C203069C1DbfFE4348c372","0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7"]

contract MProfyDAO is ReentrancyGuard{

    // Enumeration for different types of proposals
    enum ProposalType { OPEN,TREASURY,COMPLIANCE,TREASURY_MAN,FUNDING }

    // Enumeration for different statuses of proposals
    enum ProposalStatus { PENDING,LIVE,COMPLETED,FAILED,DELETED }

 // Structure representing a proposal
    struct Proposal{
        uint PID;
        address creator;
        string title;
        string description;
        uint vote_start;
        uint vote_end;
        ProposalType ptype;
        bool pPassed;
        ProposalStatus pStatus;
        uint yVotes;
        uint nVotes;
        uint minVotes;
        uint minPercent;
        string fileLink;
        string videoLink;
        address receiver;
        uint amount;
        string mail;
    }

//"t1","d1",0,0,0,"","","",0

    using Math for uint256;

    Proposal[] private  proposals;
    // Proposal[] private  complianceProposals;

    address[] private topTreasuryHolders; 


    uint private pendingProposals;

    mapping (address=> uint[]) private uProposals;  

    uint private constant PERCENT = 100;

    mapping  (uint=>mapping (address=>bool)) private complianerVotes;

//should this be cleared after voting is completed or has any usecase ?
    mapping  (uint=>mapping (address=>int)) private voterVotes;

    event ProposalAdded(
        uint indexed proposalID,
        address recipient,
        uint amount,
        string description
    );

 event ProposalStatusChanged(uint indexed proposalID, ProposalStatus status);
    event Voted(uint indexed proposalID, bool position, address indexed voter);
    event ProposalTallied(uint indexed proposalID, bool result);

    IERC20 private deedToken;
    IERC20 private treasureToken;
    address[] private complianceMembers;

    

    constructor(IERC20 _dToken,IERC20 _tToken,address[] memory _complianers){
        require(address(_dToken) != address(0) && address(_tToken) != address(0), "Invalid token address");

        deedToken = _dToken;
        treasureToken = _tToken;
        complianceMembers = _complianers;
    }

    address[] private treasureMngQueue ;

//only for test public
  function isComplianceMember(address s) public view returns (bool){
         bool _isComplianer=false;
        for (uint i=0; i < complianceMembers.length; i++) 
        {
            if(s == complianceMembers[i])
                {
                    _isComplianer = true;
                    break ;
                }
        }
        return  _isComplianer;
    }

      // Function to check if an address is a compliance member
    modifier OnlyComplianceMember{
        require(isComplianceMember(msg.sender));
        _;
    }

    
  // Function to create a new proposal

    function createProposal(
        // address  _creator,
        string memory _title,
        string memory _description,
        uint _vote_start,
        uint _vote_end,
        ProposalType _ptype,
        string memory _attach,
        string memory _video,
        string memory _mail,
        uint amount)
         external payable    {
            Proposal memory p ;
            p.PID = proposals.length;
            p.creator = msg.sender;
            p.mail = _mail;
            p.title = _title;
            p.description = _description;
            p.vote_start = _vote_start;
            p.vote_end = _vote_end;
            p.ptype = _ptype;
            p.fileLink = _attach;
            p.videoLink =  _video;
            p.amount = amount;
            

             if(_ptype == ProposalType.FUNDING){
                require(msg.value >= amount, "invalid amount");
            }
           
            proposals.push(p);
            pendingProposals++;
            uProposals[msg.sender].push(p.PID);
            // if(p.ptype==ProposalType.COMPLIANCE){
            //     complianceProposals.push(p);
            // }
           
    }



// Function to check if a proposal is agreed by majority of compliance members
//as per the 51% above criteria
    function isProposalAgreed(uint _pId) internal view returns (bool){
        uint agreed=0;
        for (uint i=0; i< complianceMembers.length; i++) 
        {
            if(complianerVotes[_pId][complianceMembers[i]]){
                agreed+=1;
            }   
        }
        if(agreed==0) return false;
        (,uint r)  = agreed.tryMul(100);
        (,uint p) = r.tryDiv(complianceMembers.length);
        return  p>50;
    }


    // Function for compliance members to vote on a proposal
    function voteByComplianer(uint _propID,bool _supports) public  OnlyComplianceMember returns (bool _success ){
        require(_propID < proposals.length,"Invalid ID");
        Proposal storage p = proposals[_propID];
        require(p.pStatus == ProposalStatus.PENDING);        
        complianerVotes[p.PID][msg.sender] = _supports;
        _success = true;
        //check voted by all compliners
        if(_supports && isProposalAgreed(p.PID)){
            p.pStatus = ProposalStatus.LIVE;
            pendingProposals--;
        }
    
    }

    
 
    // Function to execute a proposal
    function executeProposal(uint _pId)external nonReentrant  {
        require(_pId < proposals.length,"Invalid ID");

        Proposal storage p = proposals[_pId];
        (,uint totalVotes) = p.yVotes.tryAdd(p.nVotes);
        (,uint ratio) = p.yVotes.tryMul(PERCENT);
        (,uint percent) = totalVotes.tryDiv(ratio);
        
        if(p.ptype==ProposalType.COMPLIANCE){
            bool compliant = p.yVotes == complianceMembers.length && isComplianceMember(msg.sender);
            if(!compliant){
                p.pStatus = ProposalStatus.FAILED;
                emit ProposalTallied(p.PID, false);

            }else{
                complianceMembers.push(p.creator);
            }
        require(p.yVotes == complianceMembers.length && isComplianceMember(msg.sender),"All complianceMembers need to agree for complaince");       
        }

        bool criteria = (percent >= p.minPercent) && (p.yVotes >= p.minVotes) ;

        if(!criteria){
            p.pStatus = ProposalStatus.FAILED;
            emit ProposalTallied(p.PID, false);
        }
        
        require(percent >= p.minPercent, "Min PercentVotes failed");
        require(p.yVotes >= p.minVotes, "Min Votes failed"); 

        if(p.ptype == ProposalType.FUNDING){
            //send money
            (bool sent,bytes memory bd) = payable(p.receiver).call{value:p.amount}("");
            if(!sent){
            p.pStatus = ProposalStatus.FAILED;
    emit ProposalTallied(p.PID, false);

            }
            require(sent,"Transaction Failed");            
        }

        else if(p.ptype == ProposalType.TREASURY_MAN){
            treasureMngQueue.push(p.creator);
        }


        p.pStatus = ProposalStatus.COMPLETED;
    emit ProposalStatusChanged(p.PID, ProposalStatus.COMPLETED);

    }


// Function to check if an address is a top treasury holder
    function isTopTreasurer(address sender)internal view  returns  (bool){
        for (uint i =0; i < topTreasuryHolders.length;i++) 
        {
            if(topTreasuryHolders[i] == sender){
                return true;
            }
        }

        return  false;
    }

 // Function to get the voting power of an address
  function getVotingPower(address s)public   view  returns  (uint){
        uint votes = Math.max(1,deedToken.balanceOf(s));
        if(treasureToken.balanceOf(s) > 0){
            (,uint r) = treasureToken.balanceOf(s).tryDiv(10);
           votes *= r;
        }
        return  votes;
    }


    // Function for users to vote on a proposal
    //For Every Type of proposal calculates the votes accordingly
    //by making sure the voting is done in timeline
    function voteByUser(uint _propID,bool _supports)public  returns  (bool){
        require(_propID < proposals.length,"Invalid ID");
     Proposal storage p = proposals[_propID];
     require(voterVotes[_propID][msg.sender]==0,"user already voted");
        require(p.pStatus == ProposalStatus.LIVE,"status not live");
        require((block.timestamp >= p.vote_start) &&(block.timestamp <= p.vote_end),"voting closed");
        uint votes = getVotingPower(msg.sender);
        if(p.ptype == ProposalType.OPEN){
              require(deedToken.balanceOf(msg.sender) > 0,"Deed Tokens Required for Open Voting");  
         if(_supports){
                p.yVotes+=votes;
                voterVotes[_propID][msg.sender] = int256(votes);
            }else{
                p.nVotes+=votes;
                voterVotes[_propID][msg.sender] = -int256(votes);

            }
        }
        else if(p.ptype == ProposalType.TREASURY){
              require(treasureToken.balanceOf(msg.sender) > 0,"Treasure Token required for treasure voting");
               if(_supports){
                p.yVotes+=votes;
                voterVotes[_propID][msg.sender] = int256(votes);

            }else{
                p.nVotes+=votes;
                voterVotes[_propID][msg.sender] = -int256(votes);

            }  
        }
        else if(p.ptype == ProposalType.COMPLIANCE && isComplianceMember(msg.sender)){
            if(_supports){
                p.yVotes+=1;
                voterVotes[_propID][msg.sender] = 1;

            }else{
                p.nVotes+=1;
                voterVotes[_propID][msg.sender] = -1;

            }
        }
        else if(p.ptype == ProposalType.TREASURY_MAN && isTopTreasurer(msg.sender)){
            (,uint r) = treasureToken.balanceOf(msg.sender).tryDiv(10);
            if(_supports){

                            p.yVotes+=r;
                voterVotes[_propID][msg.sender] = int256(votes);
                      
                        }else{
                            p.nVotes+=r;
                voterVotes[_propID][msg.sender] = -int256(votes);
                      
                        }  
        }

       
    emit Voted(p.PID,_supports, msg.sender);

        return  true;
    }

   


  // Function to withdraw a vote by a user
   function withdrawVote(uint _propID)public  returns  (bool){
     require(voterVotes[_propID][msg.sender]!=0,"user not voted");
        require(_propID < proposals.length,"Invalid ID");

     Proposal storage p = proposals[_propID];
        uint votes = uint256(voterVotes[_propID][msg.sender]);
        require(p.pStatus == ProposalStatus.LIVE && votes!=0);
        bool _supports = votes > 0 ;
        if(p.ptype == ProposalType.OPEN){
              require(deedToken.balanceOf(msg.sender) > 0);  
         if(_supports){
                p.yVotes-=votes;
            }else{
                p.nVotes-=votes;
            }
        }
        else if(p.ptype == ProposalType.TREASURY){
              require(treasureToken.balanceOf(msg.sender) > 0);
               if(_supports){
                p.yVotes-=votes;
            }else{
                p.nVotes-=votes;
            }  
        }
        else if(p.ptype == ProposalType.COMPLIANCE && isComplianceMember(msg.sender)){
            if(_supports){
                p.yVotes-=1;
            }else{
                p.nVotes-=1;
            }
        }
        else if(p.ptype == ProposalType.TREASURY_MAN && isTopTreasurer(msg.sender)){
            (,uint r) = treasureToken.balanceOf(msg.sender).tryDiv(10);
           
            if(_supports){
                            p.yVotes-=r;
                        }else{
                            p.nVotes-=r;
                        }  
        }
       

        return  true;
    }


    // Function to delete a proposal
    function deleteProposal(uint pId) external  {
        require(pId < proposals.length,"Invalid ID");
        require(proposals[pId].creator == msg.sender,"invalid op");
        require(proposals[pId].pStatus == ProposalStatus.LIVE, "Not Live");
        proposals[pId].pStatus = ProposalStatus.DELETED;
        emit ProposalStatusChanged(pId, ProposalStatus.DELETED);
    }

    //only for Treasury Contract once use
    function getTreasuryManagerQueue() internal returns (address[] memory) {
        address[] memory tmq = treasureMngQueue;
        for (uint i = 0; i < treasureMngQueue.length; i++) {
            delete treasureMngQueue[i];
        }
        return tmq;
    }


    // Function to get the queue of treasury managers
     function getTreasuryManagerQueue() public view returns (address[] memory) {
            return treasureMngQueue;
     }
   
   // Modifier to restrict access to the treasury contract only
    modifier onlyTreasuryContract {
        require(msg.sender == 0xBF77293F2166B6Dd5292325Dd76D0d0fC14996F0);//TODO:real address
        _;
    }

 // Function to set top treasury holders
    function setTopTreasuryHolders(address[] memory _tth) external onlyTreasuryContract{
        topTreasuryHolders = _tth; 
    }

  // Function to get a specific proposal by ID
    function getProposal(uint pID) public view returns (Proposal memory){
        require(pID < proposals.length,"Invalid ID");
        return  proposals[pID];
    }


  // Function to get the number of proposals
    function  numOfProposals() external view  returns  (uint){
        return  proposals.length;
    }

   // Function to get proposals created by the caller
    function getCreatorProposals() external  view returns (Proposal[] memory){
            uint [] memory upids = uProposals[msg.sender];
            Proposal[] memory mps = new Proposal[](upids.length);
            for (uint i=0; i < upids.length;i++) 
            {
                mps[i] = proposals[upids[i]];
            }
            return  mps;
    }



    // Function to get the number of 'Yay' votes for a proposal
    function getProposalYayVotes(uint _pid) external  view  returns  (uint){
        require(_pid < proposals.length,"Invalid ID");
        return  proposals[_pid].yVotes;
    }


// Function to get the number of 'Nay' votes for a proposal
    function getProposalNayVotes(uint _pid) external view   returns  (uint){
        require(_pid < proposals.length,"Invalid ID");
        return  proposals[_pid].nVotes;
    }
        // Function to get the status of a proposal
    function getProposalStatus(uint _pid) external view   returns  (ProposalStatus ){
        require(_pid < proposals.length,"Invalid ID");
        return  proposals[_pid].pStatus;
    }

    // Function to calculate the total votes for a proposal
    function calculateVotes(uint _pid) external  view    returns  (uint){
        require(_pid < proposals.length,"Invalid ID");
        return  proposals[_pid].yVotes + proposals[_pid].nVotes;
    }
    
       // Function to get all pending proposals for compliance members
    function getPendingProposals()  public OnlyComplianceMember view  returns (Proposal[] memory){
        
        Proposal[] memory  penProps = new Proposal[](pendingProposals);
        uint ci=0;
        for (uint i=0; i<proposals.length; i++) 
        {   
            if(proposals[i].pStatus==ProposalStatus.PENDING){
            penProps[ci] = proposals[i];
            ci++;   
            }
        }
        return penProps;
    }


    // Function to get all compliance members
    function getComplianers() public view returns (address[] memory){
        return complianceMembers;
    }

    


}