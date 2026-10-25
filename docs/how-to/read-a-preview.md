# Read a preview

Every module that changes anything shows the same breakdown.

- **Group row:** a checkbox for the whole group, the count, the total size, and the riskiest verdict inside.
- **Step row:** the name, the path, the size, the [verdict](../reference/verdicts.md), and the reason in one line.
- **Facts:** the details behind the reason, such as when it was modified, who signed it, how it comes back, and how to undo it.
- **Lock shield:** the step needs admin. macOS asks for your password when it runs.
- **Show commands:** the shell line each step stands for.
- **Export:** **Copy as Script** puts the plan on the clipboard as a commented script. **Save Plan as JSON…** saves it to diff or keep.
- **Right-click a step:** **Reveal in Finder**, **Never Touch This**, or **Copy Command**.

After **Preview**, a step that would fail shows ✗ and the reason. Run stays locked until you preview, and it locks again if you change the choice.
