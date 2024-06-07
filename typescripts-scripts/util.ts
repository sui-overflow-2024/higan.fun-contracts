import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";

type Config = {
  network: string;
  packageId: string;
  managerContractId: string;
  suiCoinMetadataId: string;
  kriyaProtocolConfigsId: string;
  keyPair: Ed25519Keypair;
  bondingCurveId: string;
  sourceCoinMetadataId: string;
  moduleName: string;
};
export const loadConfigFromEnv = (): Config => {
  const privateKey = process.env.PRIVATE_KEY;
  const privateKeyMnemonic = process.env.PRIVATE_KEY_MNEMONIC;
  const packageId = process.env.PACKAGE_ID;
  const managerContractId = process.env.MANAGER_CONTRACT_ID;
  const suiCoinMetadataId = process.env.SUI_COIN_METADATA_ID;
  const kriyaProtocolConfigsId = process.env.KRIYA_PROTOCOL_CONFIGS_ID;
  const bondingCurveId = process.env.BONDING_CURVE_ID;
  const sourceCoinMetadataId = process.env.SOURCE_COIN_METADATA_ID;
  const moduleName = process.env.MODULE_NAME;
  console.log("packageId", packageId);
  if (
    !packageId ||
    !privateKeyMnemonic ||
    !managerContractId ||
    !suiCoinMetadataId ||
    !kriyaProtocolConfigsId ||
    !bondingCurveId ||
    !sourceCoinMetadataId ||
    !moduleName
  ) {
    throw new Error(
      "PACKAGE_ID or EXAMPLE_STORE_ID or PRIVATE_KEY_MNEMONIC environment variables not provided"
    );
  }

  //You can get this with  sui keytool export --key-identity modest-hypersthene
  //   const { schema, secretKey } = decodeSuiPrivateKey(privateKey || "");
  //   const keypair = Ed25519Keypair.fromSecretKey(secretKey);
  const keypair = Ed25519Keypair.deriveKeypair(privateKeyMnemonic);
  return {
    network: process.env.NETWORK || "devnet",
    packageId,
    keyPair: keypair,
    managerContractId,
    suiCoinMetadataId,
    kriyaProtocolConfigsId,
    bondingCurveId,
    sourceCoinMetadataId,
    moduleName,
  };
};
