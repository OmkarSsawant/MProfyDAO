import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { MProfyDAO } from "../typechain-types";

describe("MProfyDAO",async function () {
  let owner, dato, to, tadto, no, c1, c2, c3, c4, c5, u1, u2;
  
  before(async () => {
    [owner, dato, to, tadto, no, c1, c2, c3, c4, c5, u1, u2] = await hre.ethers.getSigners();
 
  });

  async function deployOneYearDAOFixture() {


    const MProfyDAO = await hre.ethers.getContractFactory("MProfyDAO");
    const DeedToken = await hre.ethers.getContractFactory("DeedToken");
    const TreasuryToken = await hre.ethers.getContractFactory("TreasuryToken");
    const dta = await (await DeedToken.deploy()).getAddress();
    const tta = await (await TreasuryToken.deploy()).getAddress();

    const mprofydao = await MProfyDAO.deploy(dta,tta,[c1,c2,c3,c4,c5]);

    return { mprofydao};
  }


    
    const allVoted =  (pid:number,doa:MProfyDAO) => {
      [c1,c2,c3,c4,c5].forEach(async c => {
        doa.connect(c);
        await   doa.voteByComplianer(pid,true);
        if(c== c5){
          //last index
      expect(await doa.getProposalStatus(0)).to.equal(1);
        }
      });
    }
   
     


    describe("Proposal Approval[Compliance vote]",()=>{
    
      
      it("creates  a proposal ",async()=>{
        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        await mprofydao.createProposal("title","open-description",0,0,0,"","","",0);
    
      expect(await mprofydao.numOfProposals()).to.above(0);
      })
      it("only complianers can vote",async()=>{
        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        await mprofydao.createProposal("title","open-description",0,0,0,"","","",0);
    
        expect(async()=>  await mprofydao.voteByComplianer(0,true)).to.throw;
      })  
      
      it("not live until all vote",async()=>{
        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        await mprofydao.createProposal("title","open-description",0,0,0,"","","",0);
        await mprofydao.connect(c1).voteByComplianer(0,true)
        console.log("nop",await mprofydao.numOfProposals());        
          expect(await mprofydao.getProposalStatus(0)).to.equal(0);
        })
        
        it("live on all votes",async()=>{
          const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
          allVoted(0,mprofydao)
        });
    })

    describe("Proposal Voting",()=>{
      
      it("has power",async()=> {
        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        await mprofydao.createProposal("title","open-description",0,0,0,"","","",0);
      mprofydao.connect(tadto); //similar 2 tests are applicable by just changing the dato=> dt,tt
      
          expect(await mprofydao.getVotingPower(tadto)).to.above(0);
      });

      it("votes on power",async()=> {
        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        await mprofydao.createProposal("title","open-description",0,0,0,"","","",0);
        mprofydao.connect(tadto); //similar 2 tests are applicable by just changing the dato=> dt,tt
        allVoted(0,mprofydao);
        setTimeout(async() => {
          await mprofydao.voteByUser(0,true);

        expect(await mprofydao.getVotingPower(tadto)).to.equal(await mprofydao.getProposalYayVotes(0));
        }, 5_000);
       
    });
      it("one voter can vote only once",async()=>{
        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        mprofydao.connect(tadto); //similar 2 tests are applicable by just changing the dato=> dt,tt
        await mprofydao.createProposal("title","open-description",0,0,0,"","","",0);
        allVoted(0,mprofydao);
        setTimeout(async() => {

        await mprofydao.voteByUser(0,true);
        expect(async()=> await mprofydao.voteByUser(0,true)).to.throw;
      }, 5_000);

      });

      it("unvoting updates on power",async()=>{
        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        mprofydao.connect(tadto); //similar 2 tests are applicable by just changing the dato=> dt,tt
        await mprofydao.createProposal("title","open-description",0,0,0,"","","",0);
        allVoted(0,mprofydao);
        setTimeout(async() => {

       
        await mprofydao.voteByUser(0,true);
        await mprofydao.withdrawVote(0);
        expect(await mprofydao.getProposalYayVotes(0)).to.equal(0);
      }, 5_000);

      })

      it("vote-all",async()=> {
        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        for (let i = 1; i < 5; i++) {
          allVoted(i,mprofydao)          
        }
      })
      
    })

    describe("Proposal Execution",()=>{
      it("Open Proposal Executes",async()=>{

        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        mprofydao.connect(tadto); //similar 2 tests are applicable by just changing the dato=> dt,tt
        await mprofydao.createProposal("title","open-description",0,0,0,"","","",0);
        allVoted(0,mprofydao);
        setTimeout(async() => {
          await mprofydao.voteByUser(0,true);
          await mprofydao.executeProposal(0);
          expect(await mprofydao.getProposalStatus(0)).to.equal(2);
      }, 5_000);

          
      });
      
      it("Treasury Proposal Executes",async()=>{   
        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        mprofydao.connect(tadto); //similar 2 tests are applicable by just changing the dato=> dt,tt
        await mprofydao.createProposal("title","Treasury-description",0,0,1,"","","",0);
        allVoted(0,mprofydao);
        setTimeout(async() => {
          await mprofydao.voteByUser(0,true);
          await mprofydao.executeProposal(0);
          expect(await mprofydao.getProposalStatus(0)).to.equal(2);
      }, 5_000);    
         
      });
      it("Treasury Manager Proposal Executes",async()=>{
        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        mprofydao.connect(u2); //similar 2 tests are applicable by just changing the dato=> dt,tt
        await mprofydao.createProposal("title","Treasury-description",0,0,2,"","","",0);
        allVoted(0,mprofydao);
        setTimeout(async() => {
          await mprofydao.voteByUser(0,true);
          const prev = await mprofydao.getTreasuryManagerQ();
          await mprofydao.executeProposal(0);
          expect(await mprofydao.getProposalStatus(0)).to.equal(2);
          expect((await mprofydao.getTreasuryManagerQ()).length).above(prev);
          
      }, 5_000);    
         
      });
      it("Compliance Proposal Executes",async()=>{
        // await mprofydao.executeProposal(3);
        //   //check in complianer 
        //   const applicant = (await mprofydao.getProposal(3)).creator;
        //   expect(await mprofydao.getProposalStatus(2)).to.equal(2);
        //   expect(await mprofydao.isComplianer(applicant)).to.true;
        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        mprofydao.connect(u1); //similar 2 tests are applicable by just changing the dato=> dt,tt
        await mprofydao.createProposal("title","Treasury-description",0,0,2,"","","",0);
        allVoted(0,mprofydao);
        setTimeout(async() => {
          await mprofydao.voteByUser(0,true);
          const prev = await mprofydao.getComplianers();
          await mprofydao.executeProposal(0);
          expect(await mprofydao.getProposalStatus(0)).to.equal(2);
          expect((await mprofydao.getComplianers()).length).above(prev);
          
      }, 5_000);    
      });
      it("Funding Proposal Executes",async()=>{
        const { mprofydao} =  await loadFixture(deployOneYearDAOFixture);
        mprofydao.connect(dato); //similar 2 tests are applicable by just changing the dato=> dt,tt
        await mprofydao.createProposal("title","Funding-description",0,0,4,"","","",hre.ethers.parseUnits("1","ether")
        ,{value:hre.ethers.parseUnits("1","ether")});

        allVoted(0,mprofydao);
        setTimeout(async() => {
          await mprofydao.voteByUser(0,true);
          await mprofydao.executeProposal(0);
          expect(await mprofydao.getProposalStatus(0)).to.equal(2);
          expect(hre.ethers.provider.getBalance(await mprofydao.getAddress())).to.equal(0);

        }, 5_000);    
        //check of txn
      });
  });
});
