const prisma = require('../config/prisma');

const listCorridors = async (req, res, next) => {
  try {
    const corridors = await prisma.corridor.findMany({
      include: {
        hubs: { orderBy: { sequence: 'asc' }, include: { hub: true } },
      },
      orderBy: { name: 'asc' },
    });
    res.json({ success: true, count: corridors.length, data: corridors });
  } catch (error) { next(error); }
};

const getCorridor = async (req, res, next) => {
  try {
    const corridor = await prisma.corridor.findUnique({
      where: { id: req.params.id },
      include: { hubs: { orderBy: { sequence: 'asc' }, include: { hub: true } } },
    });
    if (!corridor) return res.status(404).json({ success: false, message: 'Corridor not found' });
    res.json({ success: true, data: corridor });
  } catch (error) { next(error); }
};

module.exports = { listCorridors, getCorridor };
