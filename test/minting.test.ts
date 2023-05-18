import {ethers} from "hardhat";
import { expect } from "chai";
import {BigNumber} from "ethers";

describe("Minting", () => {
	it("should let users mint with USD", async () => {
		const [owner, otherAccount] = await ethers.getSigners();
		const TokenFactory = await ethers.getContractFactory("Token");
		const CreonPassFactory = await ethers.getContractFactory("CreonPass");
		const busdContract = await TokenFactory.deploy("BUSD", "BUSD");
		const usdtContract = await TokenFactory.deploy("USDT", "USDT");
		const creonPassContract = await CreonPassFactory.deploy(usdtContract.address, busdContract.address);
		await busdContract.mint(owner.address, ethers.utils.parseEther("1000"));
		await expect(creonPassContract.usdMint("CousinCrypto", busdContract.address, ethers.utils.parseEther("1550")))
			.to.be.revertedWith("ERC20: insufficient allowance");
		await expect(creonPassContract.usdMint("CousinCrypto", otherAccount.address, ethers.utils.parseEther("1550")))
			.to.be.revertedWith("Unrecognized USD token contract!");
		await busdContract.approve(creonPassContract.address, ethers.constants.MaxUint256);
		await expect(creonPassContract.usdMint("CousinCrypto", busdContract.address, ethers.utils.parseEther("154")))
			.to.be.revertedWith("Invalid USD amount!");
		await expect(creonPassContract.usdMint("CousinCrypto", busdContract.address, ethers.utils.parseEther("1550")))
			.to.be.revertedWith("ERC20: transfer amount exceeds balance");
		expect(await busdContract.balanceOf(creonPassContract.address)).to.equal(0);
		const costForThreeMints = ethers.utils.parseEther("465");
		const tx = await creonPassContract.usdMint("CousinCrypto", busdContract.address, costForThreeMints);
		expect(await busdContract.balanceOf(creonPassContract.address)).to.equal(costForThreeMints);
		expect(await creonPassContract.balanceOf(owner.address)).to.equal(3);
		expect(await creonPassContract.totalSupply()).to.equal(3);
		expect(await creonPassContract.ownerOf(1)).to.equal(owner.address);
		expect(await creonPassContract.ownerOf(2)).to.equal(owner.address);
		expect(await creonPassContract.ownerOf(3)).to.equal(owner.address);
		// checking USD ReferralMint event
		const receipt = await tx.wait();
		const eventArgs = receipt.events?.find((x) => {
			return x.event === "ReferralMint";
		})?.args?.slice(0, 3) || [];
		expect(eventArgs[0]).to.equal("CousinCrypto");
		expect(eventArgs[1]).to.equal("USD");
		expect(eventArgs[2]).to.equal(costForThreeMints);
	});

	it("should let users mint with native token (BNB)", async () => {
		const [owner, _] = await ethers.getSigners();
		const CreonPassFactory = await ethers.getContractFactory("CreonPass");
		const creonPassContract = await CreonPassFactory.deploy(_.address, _.address);
		await expect(creonPassContract.nativeMint("CousinCrypto", { value: ethers.utils.parseEther("0.6") }))
			.to.be.revertedWith("Invalid Native Token amount!");
		const costForThreeMints = ethers.utils.parseEther("1.5");
		const tx = await creonPassContract.nativeMint("CousinCrypto", { value: costForThreeMints });
		expect(await creonPassContract.totalSupply()).to.equal(3);
		expect(await creonPassContract.balanceOf(owner.address)).to.equal(3);
		expect(await creonPassContract.ownerOf(1)).to.equal(owner.address);
		expect(await creonPassContract.ownerOf(2)).to.equal(owner.address);
		expect(await creonPassContract.ownerOf(3)).to.equal(owner.address);
		// checking BNB  ReferralMint event
		const receipt = await tx.wait();
		const eventArgs = receipt.events?.find((x) => {
			return x.event === "ReferralMint";
		})?.args?.slice(0, 3) || [];
		expect(eventArgs[0]).to.equal("CousinCrypto");
		expect(eventArgs[1]).to.equal("BNB");
		expect(eventArgs[2]).to.equal(costForThreeMints);
	});
})