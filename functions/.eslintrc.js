module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
  ],
  rules: {
    "max-len": "off",
    "quotes": "off",
    "indent": "off",
    "comma-dangle": "off",
    "object-curly-spacing": "off",
    "no-trailing-spaces": "off",
    "quote-props": "off",
  },
  parserOptions: {
    ecmaVersion: 2018,
  },
};
