import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";

type Config = {
  network: string;
  packageId: string;
  storeId: string;
  keyPair: Ed25519Keypair;
};
export const loadConfigFromEnv = (): Config => {
  const privateKey = process.env.PRIVATE_KEY;
  const privateKeyMnemonic = process.env.PRIVATE_KEY_MNEMONIC;
  const packageId = process.env.PACKAGE_ID;
  const exampleTokenStoreObjectId = process.env.COIN_STORE_ID;
  console.log("packageId", packageId);
  console.log("exampleTokenStoreObjectId", exampleTokenStoreObjectId);
  if (!packageId || !exampleTokenStoreObjectId || !privateKeyMnemonic) {
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
    storeId: exampleTokenStoreObjectId,
    keyPair: keypair,
  };
};
