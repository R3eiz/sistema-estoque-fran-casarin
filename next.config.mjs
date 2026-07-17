const repoName = "sistema-estoque-fran-casarin";
const isPages = process.env.GITHUB_ACTIONS === "true";

/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "export",
  devIndicators: false,
  trailingSlash: true,
  basePath: isPages ? `/${repoName}` : "",
  assetPrefix: isPages ? `/${repoName}/` : "",
  env: {
    NEXT_PUBLIC_BASE_PATH: isPages ? `/${repoName}` : ""
  }
};

export default nextConfig;
