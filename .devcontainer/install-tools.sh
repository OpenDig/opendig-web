#!/bin/sh

# Install dependencies
apk update > /dev/null
apk add --no-cache direnv ncurses > /dev/null

# Set up environment
#   We have to be careful not to overwrite an environment
#   that is already set up since this script runs every build
if grep -q 'direnv hook bash' ~/.bashrc >> /dev/null 2>&1; then
  echo ".bashrc already prepared, skipping"
else
  echo "Preparing .bashrc"
  echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
  echo 'export PS1="\[\033[0;34m\]\w\[\033[0m\] $ "' >> ~/.bashrc
fi

if [ -f ".envrc" ]; then
  echo "Skipping .envrc creation, file already exists"
else
  echo "Creating .envrc. Generating secrets for development use."
  echo "See README.md for more information."
  cp .envrc.example .envrc
  # Generate secrets
  export IMGPROXY_KEY=$(xxd -g 2 -l 64 -p /dev/random | tr -d '\n')
  export IMGPROXY_SALT=$(xxd -g 2 -l 64 -p /dev/random | tr -d '\n')
  # Replace values in .envrc
  sed -i.bak "s/^IMGPROXY_KEY=.*/IMGPROXY_KEY=$IMGPROXY_KEY/" .envrc
  rm .envrc.bak
  sed -i.bak "s/^IMGPROXY_SALT=.*/IMGPROXY_SALT=$IMGPROXY_SALT/" .envrc
  rm .envrc.bak
  unset IMGPROXY_KEY
  unset IMGPROXY_SALT
fi

# Ensure direnv knows to load the .envrc file
echo "Running \`direnv allow\`"
/bin/bash -c "cd $(pwd) && direnv allow"

if [ -d "couchdb-data" ]; then
  echo "Dev data already loaded"
else
  echo "Loading dev data"
  unzip couchdb-data-start-data.zip -d couchdb-data > /dev/null
fi

echo "Environment setup complete! Go to http://localhost:3000 to view the application. See README.md for more info"