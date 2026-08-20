import * as THREE from './vendor/three/three.module.min.js';
import { OrbitControls } from './vendor/three/addons/controls/OrbitControls.js';

const viewers = new WeakMap();
const roomColors = {
  livingRoom: 0xb9d8ca,
  kitchen: 0xd9cda8,
  diningRoom: 0xe2d6b5,
  bedroom: 0xb8cce0,
  masterBedroom: 0xaec4da,
  bathroom: 0xaed5d8,
  toilet: 0xb9dadd,
  laundry: 0xb8d3d5,
  garage: 0xc8cbc8,
  office: 0xd0bfda,
  stairs: 0xd8ceb0,
  hallway: 0xded7c4,
  closet: 0xd7d8cd,
};
const urbanContext = { sidewalkWidth: 1.8, roadWidth: 5.6, margin: 8 };
const exteriorPalettes = {
  lightMinimal: {
    sky: 0xe7edeb,
    wall: 0xf3f1eb,
    interiorWall: 0xd9d8d2,
    accent: 0xb57852,
    roof: 0x3f5053,
    lowerRoof: 0x59686b,
    glass: 0x315b63,
    windowFrame: 0xdee2df,
    door: 0xa36b48,
    garageDoor: 0x4e595c,
    lawn: 0x9dac8e,
    paving: 0xc7c4ba,
    concrete: 0xb8bbb6,
    stone: 0x767871,
    wood: 0x9b603d,
    metal: 0x2f3a3c,
    plant: 0x557452,
    plantDark: 0x36543b,
  },
  warmModern: {
    sky: 0xeeeae3,
    wall: 0xe7dfd1,
    interiorWall: 0xd4cec3,
    accent: 0x8e5b3e,
    roof: 0x403c39,
    lowerRoof: 0x57514c,
    glass: 0x294a51,
    windowFrame: 0x302f2d,
    door: 0x76503d,
    garageDoor: 0x514e49,
    lawn: 0xa2aa86,
    paving: 0xc8bfae,
    concrete: 0xb7afa2,
    stone: 0x71675d,
    wood: 0x885234,
    metal: 0x302f2d,
    plant: 0x687b4d,
    plantDark: 0x425735,
  },
  graphiteModern: {
    sky: 0xe5e9e9,
    wall: 0xd7d9d6,
    interiorWall: 0xc8cbc8,
    accent: 0x4d5c5f,
    roof: 0x252f32,
    lowerRoof: 0x343f42,
    glass: 0x183b43,
    windowFrame: 0x252d2f,
    door: 0x9a6748,
    garageDoor: 0x343c3e,
    lawn: 0x879b81,
    paving: 0xb8bab6,
    concrete: 0xaeb2b0,
    stone: 0x5c6261,
    wood: 0x9b6644,
    metal: 0x242b2d,
    plant: 0x506e4e,
    plantDark: 0x314b36,
  },
  coastalModern: {
    sky: 0xe5eff0,
    wall: 0xeee8dc,
    interiorWall: 0xd7d3ca,
    accent: 0x5d8582,
    roof: 0x617477,
    lowerRoof: 0x708184,
    glass: 0x2f626a,
    windowFrame: 0xf0eee8,
    door: 0x9c704f,
    garageDoor: 0x657174,
    lawn: 0x99ad91,
    paving: 0xd0cbc0,
    concrete: 0xbec2bd,
    stone: 0x7d8984,
    wood: 0xa46a43,
    metal: 0x405255,
    plant: 0x557a58,
    plantDark: 0x36583e,
  },
};

function switchStreetDirection(streetSide) {
  switch (streetSide) {
    case 'south': return { x: 0, z: 1 };
    case 'east': return { x: 1, z: 0 };
    case 'west': return { x: -1, z: 0 };
    default: return { x: 0, z: -1 };
  }
}

class FormaViewer {
  constructor(container, data, onRoomSelected) {
    this.container = container;
    this.data = data;
    this.onRoomSelected = onRoomSelected;
    this.pickableRooms = [];
    this.pointerStart = null;
    this.disposed = false;
    this.palette = this._paletteFor(data);

    Object.assign(container.style, {
      width: '100%',
      height: '100%',
      minWidth: '1px',
      minHeight: '1px',
      overflow: 'hidden',
      touchAction: 'none',
      cursor: 'grab',
    });

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(this.palette.sky);
    this.scene.fog = new THREE.FogExp2(this.palette.sky, 0.0045);
    this.camera = new THREE.PerspectiveCamera(38, 1, 0.05, 1000);
    this.renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: false,
      powerPreference: 'high-performance',
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    container.appendChild(this.renderer.domElement);

    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.075;
    this.controls.minDistance = 4;
    this.controls.maxDistance = 140;
    this.controls.maxPolarAngle = Math.PI * 0.485;
    this.controls.screenSpacePanning = true;
    this.raycaster = new THREE.Raycaster();
    this.pointer = new THREE.Vector2();
    this.modelRoot = new THREE.Group();
    this.scene.add(this.modelRoot);

    this._addLights();
    this._bindEvents();
    this._rebuild();
    this.resetCamera();
    this.resizeObserver = new ResizeObserver(() => this._resize());
    this.resizeObserver.observe(container);
    this._resize();
    this._animate();
  }

  update(data) {
    this.data = data;
    this.palette = this._paletteFor(data);
    this.scene.background.setHex(this.palette.sky);
    this.scene.fog.color.setHex(this.palette.sky);
    this._rebuild();
  }

  _paletteFor(data) {
    return exteriorPalettes[data.appearance?.exteriorStyle] ??
      exteriorPalettes.lightMinimal;
  }

  resetCamera() {
    const { site, levels, dimensions } = this.data;
    const occupied = levels.filter((level) => level.footprint);
    const base = occupied[0]?.footprint ?? {
      x: 0,
      y: 0,
      width: site.width,
      height: site.depth,
    };
    const centerX = base.x + base.width / 2;
    const centerZ = base.y + base.height / 2;
    const maximum = Math.max(base.width, base.height, 8);
    const buildingHeight =
      Math.max(levels.length - 1, 0) * dimensions.floorToFloorHeight +
      dimensions.wallHeight;
    const outward = switchStreetDirection(site.streetSide);
    const tangent = { x: outward.z, z: -outward.x };
    const distance = maximum * 1.15 + urbanContext.sidewalkWidth +
      urbanContext.roadWidth * 0.42;
    const lateral = maximum * 0.58;
    const cameraHeight = buildingHeight + maximum * 0.48;
    const distanceToStreet = outward.x === 0
      ? (outward.z > 0 ? site.depth - centerZ : centerZ)
      : (outward.x > 0 ? site.width - centerX : centerX);
    const targetShift = distanceToStreet + urbanContext.sidewalkWidth * 0.15;
    this.camera.position.set(
      centerX + outward.x * (targetShift + distance) + tangent.x * lateral,
      cameraHeight,
      centerZ + outward.z * (targetShift + distance) + tangent.z * lateral,
    );
    this.controls.target.set(
      centerX + outward.x * targetShift,
      buildingHeight * 0.4,
      centerZ + outward.z * targetShift,
    );
    this.controls.update();
  }

  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    cancelAnimationFrame(this.animationFrame);
    this.resizeObserver?.disconnect();
    this.renderer.domElement.removeEventListener('pointerdown', this._onPointerDown);
    this.renderer.domElement.removeEventListener('pointerup', this._onPointerUp);
    this.controls.dispose();
    this._disposeGroup(this.modelRoot);
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }

  _addLights() {
    this.scene.add(new THREE.HemisphereLight(0xf6fbff, 0x76806f, 1.55));
    const sun = new THREE.DirectionalLight(0xfff5df, 2.45);
    sun.position.set(-24, 38, 18);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    Object.assign(sun.shadow.camera, {
      near: 0.5,
      far: 120,
      left: -40,
      right: 40,
      top: 40,
      bottom: -40,
    });
    sun.shadow.bias = -0.00025;
    this.scene.add(sun);
  }

  _bindEvents() {
    this._onPointerDown = (event) => {
      this.pointerStart = { x: event.clientX, y: event.clientY };
      this.container.style.cursor = 'grabbing';
    };
    this._onPointerUp = (event) => {
      this.container.style.cursor = 'grab';
      if (!this.pointerStart) return;
      const movement = Math.hypot(
        event.clientX - this.pointerStart.x,
        event.clientY - this.pointerStart.y,
      );
      this.pointerStart = null;
      if (movement <= 5) this._selectRoom(event);
    };
    this.renderer.domElement.addEventListener('pointerdown', this._onPointerDown);
    this.renderer.domElement.addEventListener('pointerup', this._onPointerUp);
  }

  _selectRoom(event) {
    const bounds = this.renderer.domElement.getBoundingClientRect();
    if (bounds.width <= 0 || bounds.height <= 0) return;
    this.pointer.x = ((event.clientX - bounds.left) / bounds.width) * 2 - 1;
    this.pointer.y = -((event.clientY - bounds.top) / bounds.height) * 2 + 1;
    this.raycaster.setFromCamera(this.pointer, this.camera);
    const targets = this.pickableRooms.filter(
      (mesh) => mesh.userData.floorIndex === this.data.selection.floorIndex,
    );
    const hit = this.raycaster.intersectObjects(targets, false)[0];
    if (hit) {
      this.onRoomSelected(
        hit.object.userData.roomId,
        hit.object.userData.floorIndex,
      );
    }
  }

  _rebuild() {
    this._disposeGroup(this.modelRoot);
    this.scene.remove(this.modelRoot);
    this.modelRoot = new THREE.Group();
    this.scene.add(this.modelRoot);
    this.pickableRooms = [];
    this._buildSite();
    for (const level of this.data.levels) this._buildLevel(level);
    if (this.data.display?.mode !== 'cutaway') {
      this._buildLowerRoofs();
      this._buildFacadeComposition();
      this._buildLandscaping();
    }
    if (this.data.roof) this._buildRoof(this.data.roof);
  }

  _buildSite() {
    const site = this.data.site;
    const exteriorMode = this.data.display?.mode !== 'cutaway';
    const ground = new THREE.Mesh(
      new THREE.PlaneGeometry(site.width, site.depth),
      new THREE.MeshStandardMaterial({
        color: exteriorMode ? this.palette.lawn : 0xf8faf6,
        roughness: 0.98,
      }),
    );
    ground.rotation.x = -Math.PI / 2;
    ground.position.set(site.width / 2, -0.21, site.depth / 2);
    ground.receiveShadow = true;
    this.modelRoot.add(ground);
    if (exteriorMode) {
      this._buildUrbanContext(site);
    } else {
      this.modelRoot.add(this._rectangleLine(site.bounds, -0.195, 0x536367));
      this.modelRoot.add(
        this._rectangleLine(site.buildableEnvelope, -0.185, 0x89989a, true),
      );
      this._buildGrid(site);
      this._buildStreet(site);
    }
  }

  _buildGrid(site) {
    const points = [];
    for (let x = 1; x < site.width; x += 1) {
      points.push(x, -0.19, 0, x, -0.19, site.depth);
    }
    for (let z = 1; z < site.depth; z += 1) {
      points.push(0, -0.19, z, site.width, -0.19, z);
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(points, 3));
    this.modelRoot.add(
      new THREE.LineSegments(
        geometry,
        new THREE.LineBasicMaterial({
          color: 0xdfe4df,
          transparent: true,
          opacity: 0.8,
        }),
      ),
    );
  }

  _buildUrbanContext(site) {
    const { sidewalkWidth, roadWidth, margin } = urbanContext;
    let sidewalk;
    let road;
    let curb;
    let roadCenter;
    let horizontalRoad;
    switch (site.streetSide) {
      case 'south':
        sidewalk = {
          x: -margin,
          y: site.depth,
          width: site.width + margin * 2,
          height: sidewalkWidth,
        };
        curb = {
          x: -margin,
          y: site.depth + sidewalkWidth - 0.08,
          width: site.width + margin * 2,
          height: 0.16,
        };
        road = {
          x: -margin,
          y: site.depth + sidewalkWidth,
          width: site.width + margin * 2,
          height: roadWidth,
        };
        roadCenter = site.depth + sidewalkWidth + roadWidth / 2;
        horizontalRoad = true;
        break;
      case 'east':
        sidewalk = {
          x: site.width,
          y: -margin,
          width: sidewalkWidth,
          height: site.depth + margin * 2,
        };
        curb = {
          x: site.width + sidewalkWidth - 0.08,
          y: -margin,
          width: 0.16,
          height: site.depth + margin * 2,
        };
        road = {
          x: site.width + sidewalkWidth,
          y: -margin,
          width: roadWidth,
          height: site.depth + margin * 2,
        };
        roadCenter = site.width + sidewalkWidth + roadWidth / 2;
        horizontalRoad = false;
        break;
      case 'west':
        sidewalk = {
          x: -sidewalkWidth,
          y: -margin,
          width: sidewalkWidth,
          height: site.depth + margin * 2,
        };
        curb = {
          x: -sidewalkWidth - 0.08,
          y: -margin,
          width: 0.16,
          height: site.depth + margin * 2,
        };
        road = {
          x: -sidewalkWidth - roadWidth,
          y: -margin,
          width: roadWidth,
          height: site.depth + margin * 2,
        };
        roadCenter = -sidewalkWidth - roadWidth / 2;
        horizontalRoad = false;
        break;
      default:
        sidewalk = {
          x: -margin,
          y: -sidewalkWidth,
          width: site.width + margin * 2,
          height: sidewalkWidth,
        };
        curb = {
          x: -margin,
          y: -sidewalkWidth - 0.08,
          width: site.width + margin * 2,
          height: 0.16,
        };
        road = {
          x: -margin,
          y: -sidewalkWidth - roadWidth,
          width: site.width + margin * 2,
          height: roadWidth,
        };
        roadCenter = -sidewalkWidth - roadWidth / 2;
        horizontalRoad = true;
    }
    const sidewalkMesh = this._boxFromBounds(
      sidewalk,
      0.12,
      this.palette.paving,
      1,
    );
    sidewalkMesh.position.y = -0.15;
    sidewalkMesh.receiveShadow = true;
    this.modelRoot.add(sidewalkMesh);
    const roadMesh = this._boxFromBounds(road, 0.08, 0x3f4445, 1);
    roadMesh.position.y = -0.19;
    roadMesh.receiveShadow = true;
    this.modelRoot.add(roadMesh);
    const curbMesh = this._boxFromBounds(curb, 0.17, 0xd4d2cb, 1);
    curbMesh.position.y = -0.105;
    curbMesh.castShadow = true;
    curbMesh.receiveShadow = true;
    this.modelRoot.add(curbMesh);
    this._buildRoadMarkings(site, roadCenter, horizontalRoad);
  }

  _buildRoadMarkings(site, roadCenter, horizontalRoad) {
    const start = -urbanContext.margin;
    const end = (horizontalRoad ? site.width : site.depth) +
      urbanContext.margin;
    for (let cursor = start; cursor < end; cursor += 3.8) {
      const length = Math.min(2.1, end - cursor);
      const bounds = horizontalRoad
        ? { x: cursor, y: roadCenter - 0.035, width: length, height: 0.07 }
        : { x: roadCenter - 0.035, y: cursor, width: 0.07, height: length };
      const marking = this._boxFromBounds(bounds, 0.018, 0xd8bd68, 1);
      marking.position.y = -0.14;
      this.modelRoot.add(marking);
    }
  }

  _buildStreet(site) {
    const offset = 0.12;
    let start;
    let end;
    switch (site.streetSide) {
      case 'south':
        start = [0, site.depth - offset];
        end = [site.width, site.depth - offset];
        break;
      case 'east':
        start = [site.width - offset, 0];
        end = [site.width - offset, site.depth];
        break;
      case 'west':
        start = [offset, 0];
        end = [offset, site.depth];
        break;
      default:
        start = [0, offset];
        end = [site.width, offset];
    }
    const geometry = new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(start[0], -0.175, start[1]),
      new THREE.Vector3(end[0], -0.175, end[1]),
    ]);
    this.modelRoot.add(
      new THREE.Line(geometry, new THREE.LineBasicMaterial({ color: 0xb55d3f })),
    );
  }

  _buildLevel(level) {
    const active = level.floorIndex === this.data.selection.floorIndex;
    const exteriorMode = this.data.display?.mode !== 'cutaway';
    const opacity = exteriorMode || active ? 1 : 0.12;
    const group = new THREE.Group();
    group.name = `level-${level.floorIndex}`;
    this.modelRoot.add(group);
    for (const space of level.spaces) {
      const stairOpening =
        level.floorIndex > 0 && space.roomType === 'stairs';
      if (stairOpening) continue;
      const slab = this._boxFromBounds(
        space.bounds,
        level.slabThickness,
        0xd3d8d4,
        opacity,
      );
      slab.position.y = level.elevation - level.slabThickness / 2;
      slab.receiveShadow = true;
      group.add(slab);
    }
    for (const space of level.spaces) {
      const stairOpening =
        level.floorIndex > 0 && space.roomType === 'stairs';
      const selected =
        !exteriorMode && space.id === this.data.selection.roomId;
      const color = selected
        ? 0xc96d49
        : (roomColors[space.roomType] ?? 0xcbd5cf);
      if (!stairOpening) {
        const floor = this._boxFromBounds(
          space.bounds,
          0.055,
          color,
          exteriorMode ? 1 : active ? 0.98 : 0.1,
        );
        floor.position.y = level.elevation + 0.028;
        floor.userData.roomId = space.id;
        floor.userData.floorIndex = level.floorIndex;
        floor.receiveShadow = true;
        if (!exteriorMode && active) this.pickableRooms.push(floor);
        group.add(floor);
      }
      if (!exteriorMode && active) {
        const label = this._makeLabel(space.label, selected);
        label.position.set(
          space.bounds.x + space.bounds.width / 2,
          level.elevation + 0.22,
          space.bounds.y + space.bounds.height / 2,
        );
        const width = Math.min(Math.max(space.bounds.width * 0.72, 1.2), 3.5);
        label.scale.set(width, width * 0.24, 1);
        group.add(label);
      }
    }
    for (const wall of level.walls) {
      group.add(this._buildWall(wall, level.elevation, opacity));
    }
    if (exteriorMode) this._buildOpenings(level, group);
  }

  _buildWall(wall, elevation, opacity) {
    const deltaX = wall.end.x - wall.start.x;
    const deltaZ = wall.end.y - wall.start.y;
    const length = Math.hypot(deltaX, deltaZ);
    const variant = (this.data.appearance?.facadeVariant ?? 0) % 5;
    const exteriorColor = elevation < 0.1 && (variant === 1 || variant === 3)
      ? this.palette.concrete
      : elevation > 0.1 && variant === 4
        ? this.palette.concrete
        : this.palette.wall;
    const mesh = new THREE.Mesh(
      new THREE.BoxGeometry(length, wall.height, wall.thickness),
      new THREE.MeshStandardMaterial({
        color: wall.kind === 'exterior'
          ? exteriorColor
          : this.palette.interiorWall,
        roughness: 0.82,
        transparent: opacity < 1,
        opacity,
        depthWrite: opacity >= 1,
      }),
    );
    mesh.position.set(
      (wall.start.x + wall.end.x) / 2,
      elevation + wall.height / 2,
      (wall.start.y + wall.end.y) / 2,
    );
    mesh.rotation.y = -Math.atan2(deltaZ, deltaX);
    mesh.castShadow = opacity >= 1;
    mesh.receiveShadow = true;
    return mesh;
  }

  _buildOpenings(level, group) {
    const walls = new Map(level.walls.map((wall) => [wall.id, wall]));
    for (const opening of level.openings ?? []) {
      const wall = walls.get(opening.wallId);
      if (!wall) continue;
      const deltaX = wall.end.x - wall.start.x;
      const deltaZ = wall.end.y - wall.start.y;
      const length = Math.hypot(deltaX, deltaZ);
      if (length <= 0) continue;
      const horizontal = Math.abs(deltaX) >= Math.abs(deltaZ);
      const depth = wall.thickness + 0.035;
      const geometry = horizontal
        ? new THREE.BoxGeometry(opening.width, opening.height, depth)
        : new THREE.BoxGeometry(depth, opening.height, opening.width);
      const color = opening.kind === 'window'
        ? this.palette.glass
        : opening.kind === 'garageDoor'
          ? this.palette.garageDoor
          : this.palette.door;
      const panel = new THREE.Mesh(
        geometry,
        opening.kind === 'window'
          ? new THREE.MeshPhysicalMaterial({
              color,
              roughness: 0.12,
              metalness: 0.18,
              transparent: true,
              opacity: 0.88,
              clearcoat: 0.45,
              emissive: 0x0d1718,
              emissiveIntensity: 0.18,
            })
          : new THREE.MeshStandardMaterial({
              color,
              roughness: 0.68,
              metalness: 0.04,
            }),
      );
      const ratio = opening.centerOffset / length;
      const centerX = wall.start.x + deltaX * ratio;
      const centerZ = wall.start.y + deltaZ * ratio;
      panel.position.set(
        centerX,
        level.elevation + opening.sillHeight + opening.height / 2,
        centerZ,
      );
      panel.castShadow = true;
      const frame = new THREE.LineSegments(
        new THREE.EdgesGeometry(geometry),
        new THREE.LineBasicMaterial({
          color: opening.kind === 'window'
            ? this.palette.windowFrame
            : 0x303638,
        }),
      );
      panel.add(frame);
      this._addOpeningDetail(panel, opening, horizontal, depth);
      group.add(panel);
      if (opening.kind === 'garageDoor') {
        this._buildDriveway(centerX, centerZ, opening.width, group);
      } else if (opening.kind === 'door' && level.floorIndex === 0) {
        this._buildEntranceFeature(level, opening, wall, centerX, centerZ, group);
        this._buildWalkway(centerX, centerZ, group);
      }
    }
  }

  _addOpeningDetail(panel, opening, horizontal, depth) {
    const frameMaterial = new THREE.MeshStandardMaterial({
      color: this.palette.windowFrame,
      roughness: 0.55,
    });
    if (opening.kind === 'window') {
      const variant = this.data.appearance?.facadeVariant ?? 0;
      const divisions = opening.width > 2.15 ? [-0.22, 0.22] : [0];
      for (const position of divisions) {
        const vertical = new THREE.Mesh(
          horizontal
            ? new THREE.BoxGeometry(0.045, opening.height * 0.94, depth + 0.012)
            : new THREE.BoxGeometry(depth + 0.012, opening.height * 0.94, 0.045),
          frameMaterial.clone(),
        );
        if (horizontal) {
          vertical.position.x = opening.width * position;
        } else {
          vertical.position.z = opening.width * position;
        }
        panel.add(vertical);
      }
      if (variant === 1 || (variant === 2 && opening.width > 1.25)) {
        const horizontalBar = new THREE.Mesh(
          horizontal
            ? new THREE.BoxGeometry(opening.width * 0.94, 0.045, depth + 0.014)
            : new THREE.BoxGeometry(depth + 0.014, 0.045, opening.width * 0.94),
          frameMaterial.clone(),
        );
        panel.add(horizontalBar);
      }
      if (opening.width > 1.65 && (variant === 1 || variant === 4)) {
        const shade = new THREE.Mesh(
          horizontal
            ? new THREE.BoxGeometry(opening.width + 0.34, 0.11, depth + 0.46)
            : new THREE.BoxGeometry(depth + 0.46, 0.11, opening.width + 0.34),
          new THREE.MeshStandardMaterial({
            color: this.palette.metal,
            roughness: 0.7,
            metalness: 0.16,
          }),
        );
        shade.position.y = opening.height / 2 + 0.12;
        shade.castShadow = true;
        panel.add(shade);
      }
      return;
    }
    if (opening.kind === 'garageDoor') {
      for (let y = -opening.height / 2 + 0.32; y < opening.height / 2; y += 0.34) {
        const slat = new THREE.Mesh(
          horizontal
            ? new THREE.BoxGeometry(opening.width * 0.94, 0.018, depth + 0.014)
            : new THREE.BoxGeometry(depth + 0.014, 0.018, opening.width * 0.94),
          new THREE.MeshStandardMaterial({ color: 0x899092, roughness: 0.7 }),
        );
        slat.position.y = y;
        panel.add(slat);
      }
    }
  }

  _buildEntranceFeature(level, opening, wall, centerX, centerZ, group) {
    const variant = this.data.appearance?.facadeVariant ?? 0;
    const outward = this._streetOutward();
    const horizontal = Math.abs(wall.end.x - wall.start.x) >=
      Math.abs(wall.end.y - wall.start.y);
    const canopyWidth = opening.width + (variant === 1 ? 1.4 : 1.0);
    const canopyDepth = variant === 2 ? 0.72 : 1.02;
    const canopy = new THREE.Mesh(
      horizontal
        ? new THREE.BoxGeometry(canopyWidth, 0.13, canopyDepth)
        : new THREE.BoxGeometry(canopyDepth, 0.13, canopyWidth),
      new THREE.MeshStandardMaterial({
        color: this.palette.accent,
        roughness: 0.72,
      }),
    );
    canopy.position.set(
      centerX + outward.x * canopyDepth * 0.48,
      level.elevation + opening.height + 0.24,
      centerZ + outward.z * canopyDepth * 0.48,
    );
    canopy.castShadow = true;
    group.add(canopy);

    const entryLight = new THREE.PointLight(0xffb56a, 8, 4.5, 2);
    entryLight.position.set(
      centerX + outward.x * canopyDepth * 0.72,
      level.elevation + opening.height + 0.04,
      centerZ + outward.z * canopyDepth * 0.72,
    );
    group.add(entryLight);

    if (variant !== 2) {
      const trimMaterial = new THREE.MeshStandardMaterial({
        color: this.palette.accent,
        roughness: 0.8,
      });
      for (const side of [-1, 1]) {
        const trim = new THREE.Mesh(
          horizontal
            ? new THREE.BoxGeometry(0.2, opening.height + 0.36, 0.075)
            : new THREE.BoxGeometry(0.075, opening.height + 0.36, 0.2),
          trimMaterial.clone(),
        );
        trim.position.set(
          centerX + (horizontal ? side * (opening.width / 2 + 0.18) : outward.x * 0.08),
          level.elevation + (opening.height + 0.36) / 2,
          centerZ + (horizontal ? outward.z * 0.08 : side * (opening.width / 2 + 0.18)),
        );
        trim.castShadow = true;
        group.add(trim);
      }
    }
  }

  _streetOutward() {
    return switchStreetDirection(this.data.site.streetSide);
  }

  _facadeBasis(bounds) {
    const outward = this._streetOutward();
    const tangent = { x: outward.z, z: -outward.x };
    const centerX = bounds.x + bounds.width / 2;
    const centerZ = bounds.y + bounds.height / 2;
    const halfDepth = outward.x === 0 ? bounds.height / 2 : bounds.width / 2;
    return {
      outward,
      tangent,
      x: centerX + outward.x * halfDepth,
      z: centerZ + outward.z * halfDepth,
      span: outward.x === 0 ? bounds.width : bounds.height,
    };
  }

  _facadePoint(basis, along = 0, offset = 0) {
    return {
      x: basis.x + basis.tangent.x * along + basis.outward.x * offset,
      z: basis.z + basis.tangent.z * along + basis.outward.z * offset,
    };
  }

  _facadeBox(basis, {
    along = 0,
    offset = 0,
    span,
    height,
    depth,
    elevation,
    color,
    roughness = 0.78,
    metalness = 0.02,
  }) {
    const geometry = basis.outward.x === 0
      ? new THREE.BoxGeometry(span, height, depth)
      : new THREE.BoxGeometry(depth, height, span);
    const mesh = new THREE.Mesh(
      geometry,
      new THREE.MeshStandardMaterial({ color, roughness, metalness }),
    );
    const point = this._facadePoint(basis, along, offset);
    mesh.position.set(point.x, elevation + height / 2, point.z);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    this.modelRoot.add(mesh);
    return mesh;
  }

  _buildFacadeComposition() {
    const occupied = this.data.levels
      .filter((level) => level.footprint)
      .sort((first, second) => first.floorIndex - second.floorIndex);
    if (occupied.length === 0) return;
    const ground = occupied[0];
    const upper = occupied.find((level) => level.floorIndex > 0);
    const variant = (this.data.appearance?.facadeVariant ?? 0) % 5;

    if (!upper) {
      this._buildModernFrame(ground, {
        coverage: variant === 2 ? 0.62 : 0.82,
        shift: variant === 2 ? 0.1 : 0,
        color: variant === 3 ? this.palette.metal : this.palette.concrete,
      });
      if (variant === 1 || variant === 4) this._buildFacadeFins(ground, 0.42);
      if (variant === 0 || variant === 3) this._buildPergola(ground, 0.48);
      this._buildEntryAccent(ground, variant % 2 === 0 ? 1 : -1);
      this._buildGaragePortal(
        ground,
        variant % 2 === 0 ? this.palette.metal : this.palette.concrete,
      );
      return;
    }

    switch (variant) {
      case 0:
        this._buildModernFrame(upper, {
          coverage: 1.16,
          color: this.palette.concrete,
        });
        this._buildBalcony(upper, { coverage: 0.78, shift: -0.05 });
        this._buildEntryAccent(ground, 1);
        this._buildGaragePortal(ground, this.palette.metal);
        break;
      case 1:
        this._buildBalcony(upper, { coverage: 0.82, shift: 0.04 });
        this._buildPergola(ground, 0.52);
        this._buildEntryAccent(ground, -1);
        this._buildGaragePortal(ground, this.palette.concrete);
        break;
      case 2:
        this._buildModernFrame(upper, {
          coverage: 0.88,
          shift: -0.1,
          color: this.palette.metal,
        });
        this._buildFacadeFins(upper, 0.46, 0.2);
        this._buildEntryAccent(ground, 1);
        this._buildGaragePortal(ground, this.palette.concrete);
        break;
      case 3:
        this._buildBalcony(upper, { coverage: 0.88, shift: -0.03 });
        this._buildModernFrame(upper, {
          coverage: 1.22,
          color: this.palette.concrete,
          depth: 0.48,
        });
        this._buildEntryAccent(ground, -1);
        this._buildGaragePortal(ground, this.palette.metal);
        break;
      default:
        this._buildModernFrame(upper, {
          coverage: 0.78,
          shift: 0.14,
          color: this.palette.concrete,
        });
        this._buildFacadeFins(upper, 0.34, -0.23);
        this._buildPergola(ground, 0.44);
        this._buildEntryAccent(ground, 1);
        this._buildGaragePortal(ground, this.palette.concrete);
    }
  }

  _buildModernFrame(level, {
    coverage,
    shift = 0,
    color,
    depth = 0.36,
  }) {
    const basis = this._facadeBasis(level.footprint);
    const maximumSpan = level.floorIndex > 0
      ? basis.span * 1.28
      : basis.span - 0.16;
    const frameSpan = Math.max(
      1.8,
      Math.min(maximumSpan, basis.span * coverage),
    );
    const center = basis.span * shift;
    const postWidth = Math.min(0.26, frameSpan * 0.1);
    const totalHeight = this.data.dimensions.wallHeight + 0.32;
    const frameOffset = depth / 2 + 0.08;
    for (const side of [-1, 1]) {
      this._facadeBox(basis, {
        along: center + side * (frameSpan - postWidth) / 2,
        offset: frameOffset,
        span: postWidth,
        height: totalHeight,
        depth,
        elevation: level.elevation - 0.12,
        color,
      });
    }
    for (const elevation of [
      level.elevation - 0.12,
      level.elevation + this.data.dimensions.wallHeight,
    ]) {
      this._facadeBox(basis, {
        along: center,
        offset: frameOffset,
        span: frameSpan,
        height: 0.2,
        depth,
        elevation,
        color,
      });
    }
  }

  _buildBalcony(level, { coverage, shift = 0 }) {
    const basis = this._facadeBasis(level.footprint);
    const span = Math.max(2.2, Math.min(basis.span - 0.3, basis.span * coverage));
    const along = basis.span * shift;
    const depth = 1.22;
    this._facadeBox(basis, {
      along,
      offset: depth / 2 + 0.06,
      span,
      height: 0.16,
      depth,
      elevation: level.elevation - 0.14,
      color: this.palette.concrete,
      roughness: 0.88,
    });

    const glassGeometry = basis.outward.x === 0
      ? new THREE.BoxGeometry(span - 0.18, 0.9, 0.045)
      : new THREE.BoxGeometry(0.045, 0.9, span - 0.18);
    const glass = new THREE.Mesh(
      glassGeometry,
      new THREE.MeshPhysicalMaterial({
        color: this.palette.glass,
        roughness: 0.08,
        metalness: 0.08,
        transparent: true,
        opacity: 0.5,
      }),
    );
    const point = this._facadePoint(basis, along, depth + 0.07);
    glass.position.set(point.x, level.elevation + 0.53, point.z);
    glass.castShadow = true;
    this.modelRoot.add(glass);
    this._facadeBox(basis, {
      along,
      offset: depth + 0.1,
      span,
      height: 0.055,
      depth: 0.07,
      elevation: level.elevation + 0.98,
      color: this.palette.metal,
      metalness: 0.45,
    });
    this._buildFacadeGlazing(level, basis, along, span * 0.72);
  }

  _buildFacadeGlazing(level, basis, along, span) {
    const height = Math.min(2.18, this.data.dimensions.wallHeight - 0.32);
    const geometry = basis.outward.x === 0
      ? new THREE.BoxGeometry(span, height, 0.055)
      : new THREE.BoxGeometry(0.055, height, span);
    const glazing = new THREE.Mesh(
      geometry,
      new THREE.MeshPhysicalMaterial({
        color: this.palette.glass,
        roughness: 0.08,
        metalness: 0.16,
        transparent: true,
        opacity: 0.9,
        clearcoat: 0.55,
        emissive: 0x101d1e,
        emissiveIntensity: 0.2,
      }),
    );
    const point = this._facadePoint(basis, along, 0.13);
    glazing.position.set(
      point.x,
      level.elevation + 0.16 + height / 2,
      point.z,
    );
    glazing.castShadow = true;
    this.modelRoot.add(glazing);
    for (const ratio of [-0.25, 0, 0.25]) {
      this._facadeBox(basis, {
        along: along + span * ratio,
        offset: 0.17,
        span: 0.045,
        height: height * 0.96,
        depth: 0.045,
        elevation: level.elevation + 0.2,
        color: this.palette.windowFrame,
        metalness: 0.3,
      });
    }
  }

  _buildFacadeFins(level, coverage, shift = 0) {
    const basis = this._facadeBasis(level.footprint);
    const screenSpan = Math.max(1.6, basis.span * coverage);
    const center = basis.span * shift;
    const count = Math.max(5, Math.round(screenSpan / 0.38));
    for (let index = 0; index < count; index++) {
      const ratio = count === 1 ? 0.5 : index / (count - 1);
      this._facadeBox(basis, {
        along: center - screenSpan / 2 + ratio * screenSpan,
        offset: 0.3,
        span: 0.075,
        height: this.data.dimensions.wallHeight - 0.32,
        depth: 0.62,
        elevation: level.elevation + 0.16,
        color: this.palette.wood,
        roughness: 0.68,
      });
    }
  }

  _buildPergola(level, coverage) {
    const basis = this._facadeBasis(level.footprint);
    const entry = level.openings?.find((opening) => opening.kind === 'door');
    const entryPosition = entry ? this._openingPosition(level, entry) : null;
    const center = entryPosition ? this._alongOnFacade(basis, entryPosition) : 0;
    const span = Math.max(2.1, basis.span * coverage);
    const depth = 1.35;
    const count = Math.max(6, Math.round(span / 0.36));
    for (let index = 0; index < count; index++) {
      const ratio = count === 1 ? 0.5 : index / (count - 1);
      this._facadeBox(basis, {
        along: center - span / 2 + ratio * span,
        offset: depth / 2,
        span: 0.09,
        height: 0.11,
        depth,
        elevation: level.elevation + this.data.dimensions.wallHeight + 0.03,
        color: this.palette.wood,
        roughness: 0.72,
      });
    }
    this._facadeBox(basis, {
      along: center,
      offset: depth,
      span: span + 0.12,
      height: 0.16,
      depth: 0.14,
      elevation: level.elevation + this.data.dimensions.wallHeight,
      color: this.palette.metal,
      metalness: 0.25,
    });
  }

  _buildEntryAccent(level, side) {
    const entry = level.openings?.find((opening) => opening.kind === 'door');
    if (!entry) return;
    const position = this._openingPosition(level, entry);
    if (!position) return;
    const basis = this._facadeBasis(level.footprint);
    const entryAlong = this._alongOnFacade(basis, position);
    const bladeCenter = entryAlong + side * (entry.width / 2 + 0.34);
    const bladeSpan = 0.52;
    const bladeDepth = 0.16;
    const variant = (this.data.appearance?.facadeVariant ?? 0) % 5;
    const materialColor = variant === 3
      ? this.palette.stone
      : this.palette.wood;
    this._facadeBox(basis, {
      along: bladeCenter,
      offset: bladeDepth / 2 + 0.12,
      span: bladeSpan,
      height: this.data.dimensions.wallHeight + 0.18,
      depth: bladeDepth,
      elevation: level.elevation,
      color: materialColor,
      roughness: 0.7,
    });
    for (let index = -2; index <= 2; index++) {
      this._facadeBox(basis, {
        along: bladeCenter + index * 0.095,
        offset: bladeDepth + 0.125,
        span: 0.018,
        height: this.data.dimensions.wallHeight + 0.12,
        depth: 0.018,
        elevation: level.elevation + 0.03,
        color: this.palette.metal,
        metalness: 0.18,
      });
    }
  }

  _buildGaragePortal(level, color) {
    const opening = level.openings?.find(
      (candidate) => candidate.kind === 'garageDoor',
    );
    if (!opening) return;
    const position = this._openingPosition(level, opening);
    if (!position) return;
    const basis = this._facadeBasis(level.footprint);
    const center = this._alongOnFacade(basis, position);
    const portalSpan = opening.width + 0.5;
    const depth = 0.3;
    for (const side of [-1, 1]) {
      this._facadeBox(basis, {
        along: center + side * (portalSpan - 0.18) / 2,
        offset: depth / 2 + 0.08,
        span: 0.18,
        height: opening.height + 0.34,
        depth,
        elevation: level.elevation,
        color,
      });
    }
    this._facadeBox(basis, {
      along: center,
      offset: depth / 2 + 0.08,
      span: portalSpan,
      height: 0.2,
      depth,
      elevation: level.elevation + opening.height + 0.2,
      color,
    });
  }

  _openingPosition(level, opening) {
    const wall = level.walls.find((candidate) => candidate.id === opening.wallId);
    if (!wall) return null;
    const deltaX = wall.end.x - wall.start.x;
    const deltaZ = wall.end.y - wall.start.y;
    const length = Math.hypot(deltaX, deltaZ);
    if (length <= 0) return null;
    const ratio = opening.centerOffset / length;
    return {
      x: wall.start.x + deltaX * ratio,
      z: wall.start.y + deltaZ * ratio,
    };
  }

  _alongOnFacade(basis, position) {
    return (position.x - basis.x) * basis.tangent.x +
      (position.z - basis.z) * basis.tangent.z;
  }

  _buildLandscaping() {
    const site = this.data.site;
    const lotBasis = this._facadeBasis({
      x: 0,
      y: 0,
      width: site.width,
      height: site.depth,
    });
    const edgeInset = Math.min(1.15, lotBasis.span * 0.12);
    const planterOffset = -Math.min(
      Math.max(site.frontSetback * 0.24, 0.48),
      1.15,
    );
    for (const side of [-1, 1]) {
      this._buildPlanter(
        lotBasis,
        side * (lotBasis.span / 2 - edgeInset),
        planterOffset,
      );
    }
    if (site.frontSetback >= 2.4) {
      const side = (this.data.appearance?.facadeVariant ?? 0) % 2 === 0 ? -1 : 1;
      this._buildTree(
        lotBasis,
        side * (lotBasis.span / 2 - Math.min(1.55, lotBasis.span * 0.18)),
        -Math.min(site.frontSetback * 0.55, 2.25),
      );
    }
  }

  _buildPlanter(basis, along, offset) {
    this._facadeBox(basis, {
      along,
      offset,
      span: 1.15,
      height: 0.24,
      depth: 0.48,
      elevation: -0.18,
      color: this.palette.concrete,
      roughness: 0.92,
    });
    for (let index = -2; index <= 2; index++) {
      const point = this._facadePoint(basis, along + index * 0.2, offset);
      const radius = 0.15 + (Math.abs(index) % 2) * 0.035;
      const shrub = new THREE.Mesh(
        new THREE.IcosahedronGeometry(radius, 1),
        new THREE.MeshStandardMaterial({
          color: index % 2 === 0 ? this.palette.plantDark : this.palette.plant,
          roughness: 0.96,
        }),
      );
      shrub.position.set(point.x, 0.08 + radius, point.z);
      shrub.castShadow = true;
      this.modelRoot.add(shrub);
    }
  }

  _buildTree(basis, along, offset) {
    const point = this._facadePoint(basis, along, offset);
    const trunk = new THREE.Mesh(
      new THREE.CylinderGeometry(0.09, 0.14, 1.7, 10),
      new THREE.MeshStandardMaterial({ color: 0x74543c, roughness: 0.94 }),
    );
    trunk.position.set(point.x, 0.66, point.z);
    trunk.castShadow = true;
    this.modelRoot.add(trunk);
    const foliageMaterial = new THREE.MeshStandardMaterial({
      color: this.palette.plantDark,
      roughness: 0.92,
    });
    const crowns = [
      { x: 0, y: 1.72, z: 0, radius: 0.7 },
      { x: -0.42, y: 1.62, z: 0.08, radius: 0.48 },
      { x: 0.38, y: 1.82, z: -0.08, radius: 0.52 },
    ];
    for (const crown of crowns) {
      const foliage = new THREE.Mesh(
        new THREE.IcosahedronGeometry(crown.radius, 2),
        foliageMaterial.clone(),
      );
      foliage.scale.y = 0.82;
      foliage.position.set(
        point.x + crown.x,
        crown.y,
        point.z + crown.z,
      );
      foliage.castShadow = true;
      this.modelRoot.add(foliage);
    }
  }

  _buildLowerRoofs() {
    const ground = this.data.levels.find((level) => level.floorIndex === 0);
    const upper = this.data.levels.find((level) => level.floorIndex === 1);
    if (!ground || !upper?.footprint) return;
    for (const space of ground.spaces) {
      for (const exposed of this._subtractBounds(
        space.bounds,
        upper.footprint,
      )) {
        const roof = this._boxFromBounds(
          exposed,
          0.14,
          this.palette.lowerRoof,
          1,
        );
        roof.position.y =
          ground.elevation + this.data.dimensions.wallHeight + 0.07;
        roof.castShadow = true;
        roof.receiveShadow = true;
        this.modelRoot.add(roof);
      }
    }
  }

  _subtractBounds(bounds, cut) {
    const left = Math.max(bounds.x, cut.x);
    const top = Math.max(bounds.y, cut.y);
    const right = Math.min(bounds.x + bounds.width, cut.x + cut.width);
    const bottom = Math.min(bounds.y + bounds.height, cut.y + cut.height);
    if (right - left <= 1e-6 || bottom - top <= 1e-6) return [bounds];
    const parts = [
      {
        x: bounds.x,
        y: bounds.y,
        width: bounds.width,
        height: top - bounds.y,
      },
      {
        x: bounds.x,
        y: bottom,
        width: bounds.width,
        height: bounds.y + bounds.height - bottom,
      },
      { x: bounds.x, y: top, width: left - bounds.x, height: bottom - top },
      {
        x: right,
        y: top,
        width: bounds.x + bounds.width - right,
        height: bottom - top,
      },
    ];
    return parts.filter((part) => part.width > 1e-6 && part.height > 1e-6);
  }

  _buildDriveway(centerX, centerZ, doorWidth, group) {
    const margin = 0.28;
    const bounds = this._streetPathBounds(
      centerX,
      centerZ,
      doorWidth + margin * 2,
    );
    const driveway = this._boxFromBounds(
      bounds,
      0.065,
      this.palette.paving,
      1,
    );
    driveway.position.y = -0.105;
    driveway.receiveShadow = true;
    group.add(driveway);
  }

  _buildWalkway(centerX, centerZ, group) {
    const walkway = this._boxFromBounds(
      this._streetPathBounds(centerX, centerZ, 1.15),
      0.07,
      this.palette.accent,
      1,
    );
    walkway.position.y = -0.095;
    walkway.receiveShadow = true;
    group.add(walkway);
  }

  _streetPathBounds(centerX, centerZ, width) {
    const site = this.data.site;
    const extension = urbanContext.sidewalkWidth + 0.38;
    switch (site.streetSide) {
      case 'south':
        return {
          x: centerX - width / 2,
          y: centerZ,
          width,
          height: Math.max(site.depth + extension - centerZ, 0.1),
        };
      case 'east':
        return {
          x: centerX,
          y: centerZ - width / 2,
          width: Math.max(site.width + extension - centerX, 0.1),
          height: width,
        };
      case 'west':
        return {
          x: -extension,
          y: centerZ - width / 2,
          width: Math.max(centerX + extension, 0.1),
          height: width,
        };
      default:
        return {
          x: centerX - width / 2,
          y: -extension,
          width,
          height: Math.max(centerZ + extension, 0.1),
        };
    }
  }

  _buildRoof(roof) {
    const exteriorMode = this.data.display?.mode !== 'cutaway';
    const bounds = roof.footprint;
    const overhang = roof.overhang;
    const left = bounds.x - overhang;
    const right = bounds.x + bounds.width + overhang;
    const top = bounds.y - overhang;
    const bottom = bounds.y + bounds.height + overhang;
    const eave = roof.baseElevation + 0.06;
    const ridge = eave + roof.ridgeHeight;
    if (roof.kind === 'flat') {
      const roofBounds = {
        x: left,
        y: top,
        width: right - left,
        height: bottom - top,
      };
      const slab = this._boxFromBounds(
        roofBounds,
        0.18,
        this.palette.concrete,
        exteriorMode ? 1 : 0.045,
      );
      slab.position.y = roof.baseElevation + 0.09;
      slab.castShadow = exteriorMode;
      slab.receiveShadow = true;
      this.modelRoot.add(slab);
      if (exteriorMode) {
        const parapets = [
          { x: left, y: top, width: right - left, height: 0.13 },
          { x: left, y: bottom - 0.13, width: right - left, height: 0.13 },
          { x: left, y: top, width: 0.13, height: bottom - top },
          { x: right - 0.13, y: top, width: 0.13, height: bottom - top },
        ];
        for (const parapetBounds of parapets) {
          const parapet = this._boxFromBounds(
            parapetBounds,
            0.46,
            this.palette.wall,
            1,
          );
          parapet.position.y = roof.baseElevation + 0.32;
          parapet.castShadow = true;
          this.modelRoot.add(parapet);
          const coping = this._boxFromBounds(
            parapetBounds,
            0.045,
            this.palette.metal,
            1,
          );
          coping.position.y = roof.baseElevation + 0.57;
          coping.castShadow = true;
          this.modelRoot.add(coping);
        }
      }
      return;
    }
    let positions;
    let indices;
    if (roof.ridgeAxis === 'x') {
      const middle = (top + bottom) / 2;
      const hipInset = roof.kind === 'hip' ? (bottom - top) / 2 : 0;
      positions = [
        left, eave, top,
        right, eave, top,
        right, eave, bottom,
        left, eave, bottom,
        Math.min(left + hipInset, right), ridge, middle,
        Math.max(right - hipInset, left), ridge, middle,
      ];
      indices = [0, 1, 5, 0, 5, 4, 3, 5, 2, 3, 4, 5, 0, 4, 3, 1, 2, 5];
    } else {
      const middle = (left + right) / 2;
      const hipInset = roof.kind === 'hip' ? (right - left) / 2 : 0;
      positions = [
        left, eave, top,
        left, eave, bottom,
        right, eave, bottom,
        right, eave, top,
        middle, ridge, Math.min(top + hipInset, bottom),
        middle, ridge, Math.max(bottom - hipInset, top),
      ];
      indices = [0, 1, 5, 0, 5, 4, 3, 4, 5, 3, 5, 2, 0, 4, 3, 1, 2, 5];
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute(
      'position',
      new THREE.Float32BufferAttribute(positions, 3),
    );
    geometry.setIndex(indices);
    geometry.computeVertexNormals();
    const material = new THREE.MeshStandardMaterial({
      color: this.palette.roof,
      roughness: 0.78,
      metalness: 0.04,
      side: THREE.DoubleSide,
      transparent: !exteriorMode,
      opacity: exteriorMode ? 1 : 0.045,
      depthWrite: exteriorMode,
    });
    const mesh = new THREE.Mesh(geometry, material);
    mesh.castShadow = exteriorMode;
    mesh.receiveShadow = true;
    this.modelRoot.add(mesh);
    const outline = new THREE.LineSegments(
      new THREE.EdgesGeometry(geometry, 18),
      new THREE.LineBasicMaterial({
        color: 0x334448,
        transparent: !exteriorMode,
        opacity: exteriorMode ? 0.62 : 0.18,
      }),
    );
    this.modelRoot.add(outline);
  }

  _boxFromBounds(bounds, height, color, opacity) {
    const mesh = new THREE.Mesh(
      new THREE.BoxGeometry(bounds.width, height, bounds.height),
      new THREE.MeshStandardMaterial({
        color,
        roughness: 0.88,
        transparent: opacity < 1,
        opacity,
        depthWrite: opacity >= 1,
      }),
    );
    mesh.position.x = bounds.x + bounds.width / 2;
    mesh.position.z = bounds.y + bounds.height / 2;
    return mesh;
  }

  _rectangleLine(bounds, elevation, color, dashed = false) {
    const geometry = new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(bounds.x, elevation, bounds.y),
      new THREE.Vector3(bounds.x + bounds.width, elevation, bounds.y),
      new THREE.Vector3(
        bounds.x + bounds.width,
        elevation,
        bounds.y + bounds.height,
      ),
      new THREE.Vector3(bounds.x, elevation, bounds.y + bounds.height),
    ]);
    const material = dashed
      ? new THREE.LineDashedMaterial({ color, dashSize: 0.35, gapSize: 0.22 })
      : new THREE.LineBasicMaterial({ color });
    const line = new THREE.LineLoop(geometry, material);
    if (dashed) line.computeLineDistances();
    return line;
  }

  _makeLabel(text, selected) {
    const canvas = document.createElement('canvas');
    canvas.width = 512;
    canvas.height = 128;
    const context = canvas.getContext('2d');
    context.clearRect(0, 0, canvas.width, canvas.height);
    context.fillStyle = selected
      ? 'rgba(181,93,63,0.95)'
      : 'rgba(248,250,246,0.9)';
    context.roundRect(4, 4, 504, 120, 14);
    context.fill();
    context.strokeStyle = selected ? '#8f452e' : '#879395';
    context.lineWidth = 3;
    context.stroke();
    context.fillStyle = selected ? '#ffffff' : '#26363a';
    context.font = '700 40px Arial, sans-serif';
    context.textAlign = 'center';
    context.textBaseline = 'middle';
    context.fillText(String(text).toUpperCase(), 256, 65, 480);
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    const sprite = new THREE.Sprite(
      new THREE.SpriteMaterial({ map: texture, transparent: true, depthTest: false }),
    );
    sprite.renderOrder = 20;
    return sprite;
  }

  _resize() {
    const width = Math.max(this.container.clientWidth, 1);
    const height = Math.max(this.container.clientHeight, 1);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height, false);
  }

  _animate() {
    if (this.disposed) return;
    this.animationFrame = requestAnimationFrame(() => this._animate());
    this.controls.update();
    this.renderer.render(this.scene, this.camera);
  }

  _disposeGroup(group) {
    group.traverse((object) => {
      object.geometry?.dispose();
      if (!object.material) return;
      const materials = Array.isArray(object.material)
        ? object.material
        : [object.material];
      for (const material of materials) {
        material.map?.dispose();
        material.dispose();
      }
    });
    group.clear();
  }
}

export function create(container, sceneJson, onRoomSelected) {
  dispose(container);
  viewers.set(
    container,
    new FormaViewer(container, JSON.parse(sceneJson), onRoomSelected),
  );
}

export function update(container, sceneJson) {
  viewers.get(container)?.update(JSON.parse(sceneJson));
}

export function resetCamera(container) {
  viewers.get(container)?.resetCamera();
}

export function dispose(container) {
  const viewer = viewers.get(container);
  if (!viewer) return;
  viewer.dispose();
  viewers.delete(container);
}
