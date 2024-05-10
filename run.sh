#!/bin/bash

npx tailwindcss -i ./src/css/input.css -o ./src/css/output.css --watch &> ./tailwind.log &
npm run dev