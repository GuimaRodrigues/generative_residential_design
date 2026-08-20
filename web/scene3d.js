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

class FormaViewer {
  constructor(container, data, onRoomSelected) {
    this.container = container;
    this.data = data;
    this.onRoomSelected = onRoomSelected;
    this.pickableRooms = [];
    this.pointerStart = null;
    this.disposed = false;

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
    this.scene.background = new THREE.Color(0xeceeea);
    this.scene.fog = new THREE.FogExp2(0xeceeea, 0.006);
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
    this._rebuild();
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
    this.camera.position.set(
      centerX + maximum * 1.05,
      buildingHeight + maximum * 0.78,
      centerZ + maximum * 1.12,
    );
    this.controls.target.set(centerX, buildingHeight * 0.32, centerZ);
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
    if (this.data.display?.mode !== 'cutaway') this._buildLowerRoofs();
    if (this.data.roof) this._buildRoof(this.data.roof);
  }

  _buildSite() {
    const site = this.data.site;
    const ground = new THREE.Mesh(
      new THREE.PlaneGeometry(site.width, site.depth),
      new THREE.MeshStandardMaterial({ color: 0xf8faf6, roughness: 0.96 }),
    );
    ground.rotation.x = -Math.PI / 2;
    ground.position.set(site.width / 2, -0.21, site.depth / 2);
    ground.receiveShadow = true;
    this.modelRoot.add(ground);
    this.modelRoot.add(this._rectangleLine(site.bounds, -0.195, 0x536367));
    this.modelRoot.add(
      this._rectangleLine(site.buildableEnvelope, -0.185, 0x89989a, true),
    );
    this._buildGrid(site);
    this._buildStreet(site);
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
    const mesh = new THREE.Mesh(
      new THREE.BoxGeometry(length, wall.height, wall.thickness),
      new THREE.MeshStandardMaterial({
        color: wall.kind === 'exterior' ? 0xeee9df : 0xd8d7d2,
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
        ? 0x456971
        : opening.kind === 'garageDoor'
          ? 0x596367
          : 0x895b40;
      const panel = new THREE.Mesh(
        geometry,
        new THREE.MeshStandardMaterial({
          color,
          roughness: opening.kind === 'window' ? 0.25 : 0.68,
          metalness: opening.kind === 'window' ? 0.22 : 0.04,
        }),
      );
      const ratio = opening.centerOffset / length;
      panel.position.set(
        wall.start.x + deltaX * ratio,
        level.elevation + opening.sillHeight + opening.height / 2,
        wall.start.y + deltaZ * ratio,
      );
      panel.castShadow = true;
      const frame = new THREE.LineSegments(
        new THREE.EdgesGeometry(geometry),
        new THREE.LineBasicMaterial({
          color: opening.kind === 'window' ? 0xe7e4dc : 0x3e4749,
        }),
      );
      panel.add(frame);
      group.add(panel);
      if (opening.kind === 'garageDoor') {
        this._buildDriveway(panel.position.x, panel.position.z, opening.width, group);
      }
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
        const roof = this._boxFromBounds(exposed, 0.14, 0x59676a, 1);
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
    const site = this.data.site;
    const margin = 0.28;
    let bounds;
    switch (site.streetSide) {
      case 'south':
        bounds = {
          x: centerX - doorWidth / 2 - margin,
          y: centerZ,
          width: doorWidth + margin * 2,
          height: Math.max(site.depth - centerZ, 0.1),
        };
        break;
      case 'east':
        bounds = {
          x: centerX,
          y: centerZ - doorWidth / 2 - margin,
          width: Math.max(site.width - centerX, 0.1),
          height: doorWidth + margin * 2,
        };
        break;
      case 'west':
        bounds = {
          x: 0,
          y: centerZ - doorWidth / 2 - margin,
          width: Math.max(centerX, 0.1),
          height: doorWidth + margin * 2,
        };
        break;
      default:
        bounds = {
          x: centerX - doorWidth / 2 - margin,
          y: 0,
          width: doorWidth + margin * 2,
          height: Math.max(centerZ, 0.1),
        };
    }
    const driveway = this._boxFromBounds(bounds, 0.065, 0xb9bcb8, 1);
    driveway.position.y = -0.145;
    driveway.receiveShadow = true;
    group.add(driveway);
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
    let positions;
    let indices;
    if (roof.ridgeAxis === 'x') {
      const middle = (top + bottom) / 2;
      positions = [
        left, eave, top,
        right, eave, top,
        right, eave, bottom,
        left, eave, bottom,
        left, ridge, middle,
        right, ridge, middle,
      ];
      indices = [0, 1, 5, 0, 5, 4, 3, 5, 2, 3, 4, 5, 0, 4, 3, 1, 2, 5];
    } else {
      const middle = (left + right) / 2;
      positions = [
        left, eave, top,
        left, eave, bottom,
        right, eave, bottom,
        right, eave, top,
        middle, ridge, top,
        middle, ridge, bottom,
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
      color: 0x4f5e62,
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
