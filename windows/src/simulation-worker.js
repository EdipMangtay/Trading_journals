import { simulate } from '../shared/workstation.mjs';
self.onmessage = ({ data }) => {
  try { self.postMessage({ id: data.id, result: simulate(data.trades, data.options) }); }
  catch (error) { self.postMessage({ id: data.id, error: error.message }); }
};
