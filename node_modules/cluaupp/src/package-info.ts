import { createRequire } from "node:module";
import path from "node:path";

export const projectRoot = path.resolve(__dirname, "..");

const fromPkg = createRequire(path.join(projectRoot, "package.json"));
export const pkg = fromPkg("./package.json") as { name: string; version: string };
