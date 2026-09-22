const path = require('path');

// The tests read two paths from the environment: JETS_CORE locates the shared Xrm mock core
// (`require(process.env.JETS_CORE)`) and WEBRES_PATH the built script bundle the tests execute
// in a vm sandbox. The RunJest target in Tests.Scripts.csproj passes both, so `dotnet test` and
// CI have always worked - but a bare `npx jest`, or the VS Code Jest extension, runs without
// them and every suite fails with "Cannot find module undefined".
//
// Defaulting them here keeps all three runners identical and needs no machine-specific paths in
// editor settings. An explicitly provided value still wins, so the MSBuild target stays in
// charge when it runs. Both are absolute, because WEBRES_PATH is handed to fs.existsSync and a
// relative path would depend on the working directory of whoever invoked Jest.
process.env.JETS_CORE = process.env.JETS_CORE || path.join(__dirname, 'jest-core');
process.env.WEBRES_PATH =
  process.env.WEBRES_PATH || path.join(__dirname, '..', 'Scripts.UI', 'build', '__PREFIX___main.js');

/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'jsdom',
  testMatch: ['**/tests/**/*.test.js'],
  testPathIgnorePatterns: ['/node_modules/', '/tests/_loadWebRes\\.js$']
};
