// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TREASURY_WALLET = "0x2D41234D5fBb785337EC16112f7A92D58392A1c5";
const LP_WALLET = "0x2D41234D5fBb785337EC16112f7A92D58392A1c5";
const TITHING_WALLET = "0x2D41234D5fBb785337EC16112f7A92D58392A1c5";

const VictorVoltageTokenModule = buildModule(
  "VictorVoltageTokenModule",
  (m) => {
    const victorVoltageToken = m.contract("VictorVoltageToken", [
      TREASURY_WALLET,
      LP_WALLET,
      TITHING_WALLET,
    ]);

    return { victorVoltageToken };
  }
);

export default VictorVoltageTokenModule;
