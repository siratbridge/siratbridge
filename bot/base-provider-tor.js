const { ethers } = require('ethers');
const { SocksProxyAgent } = require('socks-proxy-agent');
const fetch = require('node-fetch');

const agent = new SocksProxyAgent('socks5://127.0.0.1:9050');

class BaseProviderTor {
  constructor(rpcUrl) {
    this.rpcUrl = rpcUrl;
    this.id = 0;
  }
  
  async fetch(method, params = []) {
    // Deep-clean params: convert BigInt to hex strings recursively
    const cleanParams = this._cleanForJson(params);
    const body = JSON.stringify({
      jsonrpc: '2.0',
      method,
      params: cleanParams,
      id: ++this.id
    });
    
    const response = await fetch(this.rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      agent
    });
    
    const json = await response.json();
    if (json.error) throw new Error(json.error.message);
    return json.result;
  }
  
  async getBalance(address) {
    const result = await this.fetch('eth_getBalance', [address, 'latest']);
    return BigInt(result);
  }
  
  async call(to, data) {
    // Ensure to and data are hex strings
    const toStr = typeof to === 'string' ? to : to.toString();
    const dataStr = typeof data === 'string' ? data : data.toString();
    return await this.fetch('eth_call', [{ to: toStr, data: dataStr }, 'latest']);
  }
  
  async getBlockNumber() {
    const result = await this.fetch('eth_blockNumber');
    return parseInt(result, 16);
  }
  
  async getTransactionReceipt(txHash) {
    return await this.fetch('eth_getTransactionReceipt', [txHash]);
  }
  
  async sendRawTransaction(signedTx) {
    return await this.fetch('eth_sendRawTransaction', [signedTx]);
  }
  
  async getTransactionCount(address, blockTag = 'latest') {
    const result = await this.fetch('eth_getTransactionCount', [address, blockTag]);
    return parseInt(result, 16);
  }
  
  async gasPrice() {
    const result = await this.fetch('eth_gasPrice');
    return BigInt(result);
  }
  
  async getFeeData() {
    const gasPrice = await this.gasPrice();
    return { maxFeePerGas: gasPrice * 2n, maxPriorityFeePerGas: gasPrice, gasPrice };
  }
  
  _cleanForJson(obj) {
    if (obj === null || obj === undefined) return obj;
    if (typeof obj === 'bigint') return '0x' + obj.toString(16);
    if (Array.isArray(obj)) return obj.map(x => this._cleanForJson(x));
    if (typeof obj === 'object') {
      const cleaned = {};
      for (const [k, v] of Object.entries(obj)) {
        cleaned[k] = this._cleanForJson(v);
      }
      return cleaned;
    }
    return obj;
  }

  async estimateGas(tx) {
    // Convert BigInt fields to hex strings for JSON serialization
    const cleanTx = {};
    for (const [key, val] of Object.entries(tx)) {
      if (typeof val === 'bigint') {
        cleanTx[key] = '0x' + val.toString(16);
      } else {
        cleanTx[key] = val;
      }
    }
    const result = await this.fetch('eth_estimateGas', [cleanTx]);
    return BigInt(result);
  }
}

module.exports = { BaseProviderTor };
