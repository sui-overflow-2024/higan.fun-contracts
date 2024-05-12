import {
  TransactionArgument,
  TransactionBlock,
} from "@mysten/sui.js/transactions";
import { SuiClient, getFullnodeUrl } from "@mysten/sui.js/client";
import { Ed25519Keypair } from "@mysten/sui.js/keypairs/ed25519";
import { fromB64 } from "@mysten/sui.js/utils";
import {
  decodeSuiPrivateKey,
  encodeSuiPrivateKey,
} from "@mysten/sui.js/cryptography";

const client = new SuiClient({
  url: getFullnodeUrl("devnet"),
});
(async () => {
  // Define the amount of SUI tokens to send (in MIST)
  const oneSui = 1_000_000_000; // 1 SUI = 1,000,000,000 MIST
  const pointOneSui = 100_000_000;
  const pointZeroOneSui = 10_000_000;
  const privateKey = process.env.PRIVATE_KEY;
  const privateKeyMnemonic = process.env.PRIVATE_KEY_MNEMONIC;

  //You can get this with  sui keytool export --key-identity modest-hypersthene
  //   const { schema, secretKey } = decodeSuiPrivateKey(privateKey || "");

  const keypair = Ed25519Keypair.deriveKeypair(privateKeyMnemonic || "");
  //   const keypair = Ed25519Keypair.fromSecretKey(secretKey);
  const amountToSend = pointOneSui;

  const packageId =
    "0x86d1a481d7fa520140a0dbb57f7932168d26f0cc385510900a645530d1ef835f";
  const exampleTokenStoreObjectId =
    "0x419c2a570e60fff2b68bc90e04cc5a00db048675b18de351b06a15251d8d93b3";

  const moduleName = "token_example";

  const txb = new TransactionBlock();
  // Withdraw the specified amount of SUI tokens from the user's account
  //   txb.moveCall({
  //     target: `0x2::coin::withdraw`,
  //     arguments: [txb.pure(amountToSend)],
  //     typeArguments: ["0x2::sui::SUI"],
  //   });

  console.log("Splitting coins to pay for mint");
  const [coinToSendToMint] = txb.splitCoins(txb.gas, [pointOneSui]);
  // Call the `my_function` in the `my_module` module with the withdrawn SUI tokens
  console.log("Calling buy_token with the split coins: ", coinToSendToMint);

  txb.moveCall({
    target: `${packageId}::${moduleName}::buy_token`,
    arguments: [
      txb.object(exampleTokenStoreObjectId),
      txb.object(process.env.PAYMENT_ID || ""),
    ],
  });

  // Sign and execute the transaction
  const response = await client.signAndExecuteTransactionBlock({
    transactionBlock: txb,
    signer: keypair,
    requestType: "WaitForLocalExecution",
    options: {
      showBalanceChanges: true,
      showEffects: true,
    },
  });

  // txb.moveCall({
  //     target: "0x86d1a481d7fa520140a0dbb57f7932168d26f0cc385510900a645530d1ef835f::example_token::buy_token"
  //     arguments: [txb.pure.address("0x419c2a570e60fff2b68bc90e04cc5a00db048675b18de351b06a15251d8d93b3"), txb.mergeCoins]
  // })
})();
