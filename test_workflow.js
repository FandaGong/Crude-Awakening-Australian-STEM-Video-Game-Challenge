export const meta = { name: 'test', description: 'test' };
phase('Test');
const files = await agent('echo "hello"', {schema: {type: 'string'}});
log(files);
return { ok: true };