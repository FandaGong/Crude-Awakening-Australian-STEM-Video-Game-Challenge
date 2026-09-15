export const meta = {
  name: 'simplify_gd_scripts',
  description: 'Simplify GDScript logic and move signal connections to editor where possible',
  phases: [
    { title: 'Get file list', detail: 'Find all .gd scripts' },
    { title: 'Process scripts', detail: 'Simplify each script' }
  ]
};

phase('Get file list');
// Use an agent to find all .gd files, excluding .import folders
const files = await agent(
  'find . -name "*.gd" -type f | grep -v "\\.import" | sort'
// Note: no schema, returns string
// The output may include newlines; we need to split into lines and filter empty lines.
const fileList = files.trim().split('\n').filter(line => line.length > 0);
log(`Found ${fileList.length} .gd files`);

phase('Process scripts');
// Process each file in parallel
const results = await parallel(
  fileList.map(filePath => () =>
    agent(
      `You are a GDScript expert. Your task is to simplify the logic in the given script and make it more readable, while preserving functionality.
      You must NOT modify any comments (lines starting with # or block comments). Only change actual code.
      Specific tasks:
      1. Look for signal connections made via \`connect\` calls (e.g., \$.some_node.connect("signal_name", this, "_on_some_node_signal_name")).
         If the method being connected follows Godot's naming convention \`_on_<node>_<signal>\` (or similar clear mapping) and the node is obtained via \@onready or \$,
         consider removing the connect call and instead rely on the editor connection (i.e., delete the connect line). Replace it with a comment indicating that the signal should be connected in the editor if appropriate.
         However, do not remove the connect call if it's unclear or if the method does not match the expected pattern.
      2. Simplify complex conditionals, nested loops, and redundant code to make the logic easier to read.
         Examples: combine consecutive if statements with same condition, simplify boolean expressions, remove unnecessary else blocks, etc.
      3. Do not change the overall structure or functionality.
      4. After making changes, ensure the script is syntactically correct GDScript.

      File path: ${filePath}
      Please read the file, apply the transformations, and write the updated content back to the same path.
      You have access to Read and Write tools.`,
      {
        label: `Process ${filePath}`,
        phase: 'Process scripts'
      }
    )
  )
);

// Filter out null results (if any agent failed)
const successful = results.filter(Boolean);
log(`Successfully processed ${successful.length}/${fileList.length} files`);

return { processed: successful.length, total: fileList.length };
}