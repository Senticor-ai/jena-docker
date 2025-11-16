#!/bin/bash
#   Licensed to the Apache Software Foundation (ASF) under one or more
#   contributor license agreements.  See the NOTICE file distributed with
#   this work for additional information regarding copyright ownership.
#   The ASF licenses this file to You under the Apache License, Version 2.0
#   (the "License"); you may not use this file except in compliance with
#   the License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

set -e

# Configuration
DOCKER_USERNAME="${DOCKER_USERNAME:-yourusername}"
VERSION="5.6.0"
CONTAINER_TOOL="${CONTAINER_TOOL:-docker}"  # Can be 'docker' or 'podman'

echo "Using container tool: $CONTAINER_TOOL"
echo "Docker Hub username: $DOCKER_USERNAME"
echo "Version: $VERSION"

# Build Jena
echo ""
echo "Building Jena image..."
$CONTAINER_TOOL build -t $DOCKER_USERNAME/jena:$VERSION jena/
$CONTAINER_TOOL tag $DOCKER_USERNAME/jena:$VERSION $DOCKER_USERNAME/jena:latest

# Build Jena Fuseki
echo ""
echo "Building Jena Fuseki image..."
$CONTAINER_TOOL build -t $DOCKER_USERNAME/jena-fuseki:$VERSION jena-fuseki/
$CONTAINER_TOOL tag $DOCKER_USERNAME/jena-fuseki:$VERSION $DOCKER_USERNAME/jena-fuseki:latest

# Test images
echo ""
echo "Testing images..."
$CONTAINER_TOOL run --rm $DOCKER_USERNAME/jena:$VERSION riot --version
echo "✓ Jena image works"

# Push to registry (optional - uncomment when ready)
# echo ""
# echo "Pushing to Docker Hub..."
# $CONTAINER_TOOL login
# $CONTAINER_TOOL push $DOCKER_USERNAME/jena:$VERSION
# $CONTAINER_TOOL push $DOCKER_USERNAME/jena:latest
# $CONTAINER_TOOL push $DOCKER_USERNAME/jena-fuseki:$VERSION
# $CONTAINER_TOOL push $DOCKER_USERNAME/jena-fuseki:latest

echo ""
echo "✓ Build complete!"
echo ""
echo "Images built:"
echo "  - $DOCKER_USERNAME/jena:$VERSION"
echo "  - $DOCKER_USERNAME/jena:latest"
echo "  - $DOCKER_USERNAME/jena-fuseki:$VERSION"
echo "  - $DOCKER_USERNAME/jena-fuseki:latest"
echo ""
echo "To push to Docker Hub, uncomment the push section in this script and run:"
echo "  DOCKER_USERNAME=yourusername ./build-and-push.sh"
echo ""
echo "Or use Podman:"
echo "  CONTAINER_TOOL=podman DOCKER_USERNAME=yourusername ./build-and-push.sh"
