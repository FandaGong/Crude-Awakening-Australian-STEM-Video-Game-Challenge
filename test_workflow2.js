export const meta = { name: 'test', description: 'test' };
phase('Test');
const files = await agent('find . -name "*.gd" -type f | grep -v "\\.import" | sort');
log(files);
return { ok: true };