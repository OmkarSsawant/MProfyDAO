// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


//dt = 0xfAF646893C6D3Ef849FadD67FC1Ca3e347f409B7
//tt = 0xBF77293F2166B6Dd5292325Dd76D0d0fC14996F0
//complianers = ["0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB","0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678","0x617F2E2fD72FD9D5503197092aC168c91465E7f2","0x17F6AD8Ef982297579C203069C1DbfFE4348c372","0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7"]

contract MProfyDAO{

    
    enum ProposalType { OPEN,TREASURY,COMPLIANCE,TREASURY_MAN,FUNDING }

    enum ProposalStatus { PENDING,LIVE,COMPLETED,FAILED,DELETED }

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

    Proposal[] private  proposals;
    Proposal[] private  complianceProposals;

    address[] private topTreasuryHolders; 


    uint private pendingProposals;

    mapping (address=> uint[]) uProposals;  


    mapping  (uint=>mapping (address=>bool)) complianerVotes;

//should this be cleared after voting is completed or has any usecase
    mapping  (uint=>mapping (address=>int)) voterVotes;

    event ProposalAdded(
        uint indexed proposalID,
        address recipient,
        uint amount,
        string description
    );


    event Voted(uint indexed proposalID, bool position, address indexed voter);
    event ProposalTallied(uint indexed proposalID, bool result);

    IERC20 private deedToken;
    IERC20 private treasureToken;
    address[] complianers;

    constructor(IERC20 _dToken,IERC20 _tToken,address[] memory _complianers){
        deedToken = _dToken;
        treasureToken = _tToken;
        complianers = _complianers;
    }

    address[] private treasureMngQueue ;


    modifier OnlyComplianer{
        require(isComplianer(msg.sender));
        _;
    }


    function isComplianer(address s) internal view returns (bool){
         bool _isComplianer=false;
        for (uint i=0; i < complianers.length; i++) 
        {
            if(s == complianers[i])
                {
                    _isComplianer = true;
                    break ;
                }
        }
        return  _isComplianer;
    }

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
            if(p.ptype==ProposalType.COMPLIANCE){
                complianceProposals.push(p);
            }
           
    }



    function isProposalAgreed(uint _pId) internal view returns (bool){
        for (uint i=0; i< complianers.length; i++) 
        {
            if(!complianerVotes[_pId][complianers[i]]){
                return  false;
            }   
        }
        return  true;
    }


    function voteByComplianer(uint _propID,bool _supports) public  OnlyComplianer returns (bool _success ){
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

    
 
    function executeProposal(uint _pId)external   {
        Proposal storage p = proposals[_pId];
        uint totalVotes = SafeMath.add(p.yVotes,p.nVotes);
        uint percentile = SafeMath.mul(SafeMath.div(p.yVotes,totalVotes),100);
        
        if(p.ptype==ProposalType.COMPLIANCE){
            bool compliant = p.yVotes == complianers.length && isComplianer(msg.sender);
            if(!compliant){
                p.pStatus = ProposalStatus.FAILED;
                emit ProposalTallied(p.PID, false);

            }else{
                complianers.push(p.creator);
            }
        require(p.yVotes == complianers.length && isComplianer(msg.sender),"All Complianers need to agree for complaince");       
        }

        bool criteria = (percentile >= p.minPercent) && (p.yVotes >= p.minVotes);

        if(!criteria){
            p.pStatus = ProposalStatus.FAILED;
            emit ProposalTallied(p.PID, false);
        }
        
        require(percentile >= p.minPercent, "Min PercentVotes failed");
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
    emit ProposalTallied(p.PID, true);

    }


    function isTopTreasurer(address sender)internal view  returns  (bool){
        for (uint i =0; i < topTreasuryHolders.length;i++) 
        {
            if(topTreasuryHolders[i] == sender){
                return true;
            }
        }

        return  false;
    }

  function getVotingPower(address s)public   view  returns  (uint){
        uint votes = Math.max(1,deedToken.balanceOf(s));
        if(treasureToken.balanceOf(s) > 0){
           votes *= SafeMath.div(treasureToken.balanceOf(s),10);
        }
        return  votes;
    }


    function voteByUser(uint _propID,bool _supports)public  returns  (bool){
     Proposal storage p = proposals[_propID];
        require(p.pStatus == ProposalStatus.LIVE);
        uint votes = getVotingPower(msg.sender);
        if(p.ptype == ProposalType.OPEN){
              require(deedToken.balanceOf(msg.sender) > 0);  
         if(_supports){
                p.yVotes+=votes;
                voterVotes[_propID][msg.sender] = int256(votes);
            }else{
                p.nVotes+=votes;
                voterVotes[_propID][msg.sender] = -int256(votes);

            }
        }
        else if(p.ptype == ProposalType.TREASURY){
              require(treasureToken.balanceOf(msg.sender) > 0);
               if(_supports){
                p.yVotes+=votes;
                voterVotes[_propID][msg.sender] = int256(votes);

            }else{
                p.nVotes+=votes;
                voterVotes[_propID][msg.sender] = -int256(votes);

            }  
        }
        else if(p.ptype == ProposalType.COMPLIANCE && isComplianer(msg.sender)){
            if(_supports){
                p.yVotes+=1;
                voterVotes[_propID][msg.sender] = 1;

            }else{
                p.nVotes+=1;
                voterVotes[_propID][msg.sender] = -1;

            }
        }
        else if(p.ptype == ProposalType.TREASURY_MAN && isTopTreasurer(msg.sender)){
            if(_supports){
                            p.yVotes+=SafeMath.div(treasureToken.balanceOf(msg.sender),10);
                voterVotes[_propID][msg.sender] = int256(votes);
                      
                        }else{
                            p.nVotes+=SafeMath.div(treasureToken.balanceOf(msg.sender),10);
                voterVotes[_propID][msg.sender] = -int256(votes);
                      
                        }  
        }

       
    emit Voted(p.PID,false, msg.sender);

        return  true;
    }

   


   function withdrawVote(uint _propID)public  returns  (bool){
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
        else if(p.ptype == ProposalType.COMPLIANCE && isComplianer(msg.sender)){
            if(_supports){
                p.yVotes-=1;
            }else{
                p.nVotes-=1;
            }
        }
        else if(p.ptype == ProposalType.TREASURY_MAN && isTopTreasurer(msg.sender)){
            if(_supports){
                            p.yVotes-=SafeMath.div(treasureToken.balanceOf(msg.sender),10);
                        }else{
                            p.nVotes-=SafeMath.div(treasureToken.balanceOf(msg.sender),10);
                        }  
        }
       

        return  true;
    }

    function deleteProposal(uint pId) external  {
        require(proposals[pId].pStatus == ProposalStatus.LIVE, "Not Live");
        proposals[pId].pStatus = ProposalStatus.DELETED;
    }

    //only for Treasury Contract once use
    function getTreasuryManagerQueue() internal returns (address[] memory) {
        address[] memory tmq = treasureMngQueue;
        for (uint i = 0; i < treasureMngQueue.length; i++) {
            delete treasureMngQueue[i];
        }
        return tmq;
    }
   

    function setTopTreasuryHolders(address[] memory _tth) external {
        topTreasuryHolders = _tth; 
    }

    function getProposalInfo(uint pID) public view returns (Proposal memory){
        return  proposals[pID];
    }


    function  numOfProposals() external view  returns  (uint){
        return  proposals.length;
    }

    function getCreatorProposals() external  view returns (Proposal[] memory){
            uint [] memory upids = uProposals[msg.sender];
            Proposal[] memory mps = new Proposal[](upids.length);
            for (uint i=0; i < upids.length;i++) 
            {
                mps[i] = proposals[upids[i]];
            }
            return  mps;
    }


    function getProposalYayVotes(uint _pid) external  view  returns  (uint){
        return  proposals[_pid].yVotes;
    }


    function getProposalNayVotes(uint _pid) external view   returns  (uint){
        return  proposals[_pid].nVotes;
    }
    function getProposalStatus(uint _pid) external view   returns  (ProposalStatus ){
        return  proposals[_pid].pStatus;
    }

    function calculateVotes(uint _pid) external  view    returns  (uint){
        return  proposals[_pid].yVotes + proposals[_pid].nVotes;
    }
    
    function getPendingProposals()  public OnlyComplianer view  returns (Proposal[] memory){
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


}