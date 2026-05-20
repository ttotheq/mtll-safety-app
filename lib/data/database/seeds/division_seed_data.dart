class DivisionSeed {
  const DivisionSeed({
    required this.name,
    required this.sortOrder,
    this.ageMin,
    this.ageMax,
  });

  final String name;
  final int sortOrder;
  final int? ageMin;
  final int? ageMax;
}

const defaultDivisionSeeds = <DivisionSeed>[
  DivisionSeed(name: 'Tee Ball', sortOrder: 10),
  DivisionSeed(name: 'Rookies', sortOrder: 20),
  DivisionSeed(name: 'Farm', sortOrder: 30),
  DivisionSeed(name: 'Minors', sortOrder: 40),
  DivisionSeed(name: 'Majors', sortOrder: 50),
  DivisionSeed(name: 'Juniors', sortOrder: 60),
  DivisionSeed(name: 'Seniors', sortOrder: 70),
];
