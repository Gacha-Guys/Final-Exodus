# Team setup and GitHub sync test

Use **Godot 4.7.2 standard**, GDScript. No .NET SDK or Godot Git plugin is required. Check the version in Godot → About before importing. Do not upgrade the shared project independently.

## First run

1. Accept access to Gacha-Guys/Final-Exodus on GitHub.
2. In GitHub Desktop, clone that repository to a normal local folder (not a OneDrive/iCloud/Dropbox synced folder).
3. Fetch and pull the branch containing this starter. If it is in an open pull request, switch to its branch; after merge, use main.
4. In Godot, choose Import and select `frontend/project.godot` inside your clone. Do not create a separate new project.
5. Open the imported project and press F6 to run the open test scene, or F5 to run the project. On some laptops hold Fn too; the Play button also works.
6. The project opens the portrait account form. For the original sync test, expand Developer connection settings and select Team sync test; confirm all four names appear.

## Prove everyone's changes sync

1. Pull before starting. Create your own branch, such as `sync-test-mihai`.
2. Open YOUR file in `frontend/team_checkins/`: tyler.txt, jason.txt, mihai.txt or riley.txt.
3. Replace `Waiting for first check-in` with `Your name - Godot 4.7.2 runs on Windows/Mac` using your actual result.
4. Save, stop and rerun the game; your new text should appear.
5. In GitHub Desktop, review the changed files. Commit only your check-in change, push your branch, and open a pull request.
6. After the pull request is merged, everyone fetches/pulls main and reruns. Everyone should see that check-in.
7. Repeat for all four people. Success means all four check-ins display on all four machines, using the same merged commit.

GitHub does not live-sync unsaved edits or gameplay. You save → commit → push → merge; teammates pull. Stop the game before pulling; let Godot reload changed files before running again. Don't discard someone else's work to resolve conflicts; ask for help.

## What belongs in Git

Commit project.godot, .tscn/.tres scenes/resources, .gd scripts, .uid sidecars, original assets and docs. Ignore generated .godot caches, local settings, secrets and exported builds. A clean import can generate .uid sidecars; include them with their scripts. No large assets are needed for this starter.

## Next connection milestone

After file syncing passes: add an API health check and GDScript registration screen; test a real account write from two machines. A shared HTTPS API address is required for shared backend testing; localhost refers to the machine running Godot. Login/profile read-back comes next. This starter does not claim frontend/backend integration or completion of a Jira story.
