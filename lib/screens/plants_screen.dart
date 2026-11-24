import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/planta_service.dart';
import '../theme/app_theme.dart';

// ── Tela de Plantas ────────────────────────────────────────────────────────────
class PlantsScreen extends StatefulWidget {
  /// Torre cujas plantas aparecem (só as de quem está logado).
  final String torreId;

  /// Nome mostrado no cabeçalho. Nulo = rótulo genérico.
  final String? torreNome;

  const PlantsScreen({super.key, required this.torreId, this.torreNome});

  @override
  State<PlantsScreen> createState() => _PlantsScreenState();
}

class _PlantsScreenState extends State<PlantsScreen> {
  List<Plant> _plantas = [];
  bool        _loading = true;
  String?     _erro;

  @override
  void initState() {
    super.initState();
    _carregarPlantas();
  }

  Future<void> _carregarPlantas() async {
    setState(() { _loading = true; _erro = null; });
    try {
      final plantas = await PlantaService.listar(widget.torreId);
      setState(() { _plantas = plantas; _loading = false; });
    } catch (e) {
      setState(() { _erro = 'Erro ao carregar plantas'; _loading = false; });
    }
  }

  Future<void> _abrirModalAdicionar() async {
    final adicionada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AeroRadius.card)),
      ),
      builder: (_) => _AddPlantModal(torreId: widget.torreId),
    );
    if (adicionada == true) _carregarPlantas();
  }

  Future<void> _deletarPlanta(Plant planta) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover planta', style: TextStyle(fontFamily: AeroFonts.titulo, color: AeroColors.tinta, fontWeight: FontWeight.w900)),
        content: Text('Deseja remover "${planta.nome}"?', style: const TextStyle(color: AeroColors.tintaSuave)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AeroColors.tintaSuave)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover', style: TextStyle(color: AeroColors.erro)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await PlantaService.deletar(widget.torreId, planta.id);
        _carregarPlantas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${planta.nome} removida!'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Erro ao remover planta'),
            backgroundColor: AeroColors.erro,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? _buildErro()
              : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(height: 1, color: AeroColors.borda),
    ),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AeroColors.tintaSuave),
      onPressed: () => Navigator.pop(context),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Minhas plantas', style: TextStyle(fontFamily: AeroFonts.titulo, color: AeroColors.tinta, fontSize: 18, fontWeight: FontWeight.w900)),
        Text('AeroTower · $_nomeTorre', style: const TextStyle(fontFamily: AeroFonts.corpo, color: AeroColors.tintaSuave, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh, color: AeroColors.tintaSuave, size: 20),
        onPressed: _carregarPlantas,
      ),
    ],
  );

  Widget _buildBody() => LayoutBuilder(
    builder: (context, constraints) {
      final cols = (constraints.maxWidth / 220).floor().clamp(2, 4);
      return RefreshIndicator(
        color: AeroColors.musgo,
        onRefresh: _carregarPlantas,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGardenHeader(),
              const SizedBox(height: 16),
              _buildSummaryRow(),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('Cultivos ativos', style: TextStyle(fontFamily: AeroFonts.titulo, color: AeroColors.tinta, fontSize: 22, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  _OutlinedChip(label: '${_plantas.length} plantas'),
                ],
              ),
              const SizedBox(height: 14),
              _plantas.isEmpty
                  ? _buildVazio()
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: _plantas.length,
                      itemBuilder: (_, i) => _PlantCard(
                        plant: _plantas[i],
                        onDelete: () => _deletarPlanta(_plantas[i]),
                      ),
                    ),
              const SizedBox(height: 20),
              _AddPlantButton(onTap: _abrirModalAdicionar),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildErro() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off, color: AeroColors.tintaSuave, size: 48),
        const SizedBox(height: 16),
        const Text('Erro ao carregar plantas', style: TextStyle(color: AeroColors.tintaSuave)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _carregarPlantas,
          child: const Text('Tentar novamente'),
        ),
      ],
    ),
  );

  Widget _buildVazio() => Container(
    padding: const EdgeInsets.all(32),
    alignment: Alignment.center,
    child: const Column(
      children: [
        Icon(Icons.eco_outlined, color: AeroColors.tintaSuave, size: 48),
        SizedBox(height: 12),
        Text('Nenhuma planta cadastrada', style: TextStyle(color: AeroColors.tintaSuave)),
        SizedBox(height: 8),
        Text('Toque em "Adicionar planta" para começar', style: TextStyle(color: AeroColors.tintaSuave, fontSize: 12)),
      ],
    ),
  );

  String get _nomeTorre => widget.torreNome ?? 'Minha torre';

  Widget _buildGardenHeader() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AeroColors.areia, borderRadius: BorderRadius.circular(AeroRadius.card)),
    child: Row(
      children: [
        const CircleAvatar(radius: 22, backgroundColor: AeroColors.mintForte, child: Icon(Icons.local_florist, color: AeroColors.musgo, size: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_nomeTorre, style: const TextStyle(fontFamily: AeroFonts.titulo, color: AeroColors.tinta, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              const Text('Acompanhamento dos cultivos ativos', style: TextStyle(color: AeroColors.tintaSuave, fontSize: 12)),
            ],
          ),
        ),
        const _OutlinedChip(label: 'Aeroponia'),
      ],
    ),
  );

  Widget _buildSummaryRow() => Row(
    children: [
      Expanded(child: _SummaryCard(
        icon: Icons.check_circle_outline,
        value: '${_plantas.length}',
        label: 'Total',
        color: AeroColors.musgo,
      )),
    ],
  );

}

// ── Modal de Adicionar Planta ──────────────────────────────────────────────────
class _AddPlantModal extends StatefulWidget {
  final String torreId;

  const _AddPlantModal({required this.torreId});

  @override
  State<_AddPlantModal> createState() => _AddPlantModalState();
}

class _AddPlantModalState extends State<_AddPlantModal> {
  final _nomeCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  final _dataCtrl = TextEditingController();

  XFile?  _fotoXFile;           // ← XFile funciona em Web e Mobile
  Uint8List? _fotoBytes;        // ← bytes para preview na Web
  bool    _salvando = false;
  String? _erro;

  // O tipo é a ESPÉCIE: é o que vai para a IA como "cultura" (o nome é o
  // apelido que o dono dá). Antes eram categorias ("Folhosa"...) e o app
  // mandava o apelido para a IA.
  static const _tipos = [
    'Alface', 'Rúcula', 'Agrião', 'Couve', 'Espinafre', 'Manjericão', 'Hortelã',
    'Salsa', 'Cebolinha', 'Coentro', 'Morango', 'Tomate-cereja', 'Outra',
  ];

  Future<void> _selecionarFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _fotoXFile = picked;
        _fotoBytes = bytes;
      });
    }
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (data != null) {
      _dataCtrl.text = '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _salvar() async {
    if (_nomeCtrl.text.isEmpty || _tipoCtrl.text.isEmpty || _dataCtrl.text.isEmpty) {
      setState(() => _erro = 'Preencha todos os campos obrigatórios');
      return;
    }
    setState(() { _salvando = true; _erro = null; });
    try {
      await PlantaService.criar(
        torreId:     widget.torreId,
        nome:        _nomeCtrl.text.trim(),
        tipo:        _tipoCtrl.text.trim(),
        dataPlantio: _dataCtrl.text,
        fotoXFile:   _fotoXFile,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _erro = 'Erro ao salvar planta'; _salvando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AeroColors.borda, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Adicionar planta', style: TextStyle(fontFamily: AeroFonts.titulo, color: AeroColors.tinta, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),

            // ── Preview da foto ──────────────────────────────────────────────
            GestureDetector(
              onTap: _selecionarFoto,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AeroColors.areia,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _fotoBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.memory(_fotoBytes!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: AeroColors.tintaSuave, size: 36),
                          SizedBox(height: 8),
                          Text('Adicionar foto (opcional)', style: TextStyle(color: AeroColors.tintaSuave, fontSize: 12)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 100 caracteres: o mesmo limite do Back-End e da IA.
            _buildField(controller: _nomeCtrl, label: 'Nome da planta', hint: 'Ex: Alface 01', maxLength: 100),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              decoration: _inputDecoration('Tipo'),
              dropdownColor: AeroColors.creme,
              // O dropdown usa este estilo sem misturar com o tema: a fonte vem explícita.
              style: const TextStyle(fontFamily: AeroFonts.corpo, color: AeroColors.tinta, fontSize: 16),
              items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => _tipoCtrl.text = v ?? '',
              hint: const Text('Selecione o tipo', style: TextStyle(color: AeroColors.tintaSuave)),
            ),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: _selecionarData,
              child: AbsorbPointer(
                child: _buildField(controller: _dataCtrl, label: 'Data de plantio', hint: 'Selecionar data', suffixIcon: Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),

            if (_erro != null) ...[
              Text(_erro!, style: const TextStyle(color: AeroColors.erro, fontSize: 12)),
              const SizedBox(height: 8),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AeroColors.musgo,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _salvando
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salvar planta', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? suffixIcon,
    int? maxLength,
  }) => TextFormField(
    controller: controller,
    maxLength: maxLength,
    style: const TextStyle(color: AeroColors.tinta),
    decoration: _inputDecoration(label, hint: hint, suffixIcon: suffixIcon),
  );

  InputDecoration _inputDecoration(String label, {String? hint, IconData? suffixIcon}) => InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: AeroColors.tintaSuave, size: 18) : null,
  );
}

// ── PlantCard ──────────────────────────────────────────────────────────────────
class _PlantCard extends StatelessWidget {
  final Plant        plant;
  final VoidCallback onDelete;
  const _PlantCard({required this.plant, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fotoUrl = PlantaService.urlDaFoto(plant);

    return Container(
      decoration: BoxDecoration(
        color: AeroColors.creme,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                fotoUrl != null
                    ? Image.network(fotoUrl, fit: BoxFit.cover,
                        errorBuilder: (context, erro, pilha) => Container(
                          color: AeroColors.mint,
                          child: const Icon(Icons.eco, color: AeroColors.musgo, size: 40),
                        ),
                      )
                    : Container(color: AeroColors.mint, child: const Icon(Icons.eco, color: AeroColors.musgo, size: 40)),

                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AeroColors.creme.withValues(alpha: 0.9), shape: BoxShape.circle),
                      child: const Icon(Icons.delete_outline, color: AeroColors.erro, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plant.nome, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: AeroFonts.titulo, color: AeroColors.tinta, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 3),
                Text(plant.tipo, style: const TextStyle(color: AeroColors.tintaSuave, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 10, color: AeroColors.tintaSuave),
                    const SizedBox(width: 4),
                    Text(plant.dataPlantio, style: const TextStyle(color: AeroColors.tintaSuave, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String   value, label;
  final Color    color;
  const _SummaryCard({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: AeroColors.mint, borderRadius: BorderRadius.circular(24)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontFamily: AeroFonts.titulo, color: AeroColors.tinta, fontSize: 26, fontWeight: FontWeight.w900, height: 1)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: AeroColors.tintaSuave, fontSize: 12)),
    ]),
  );
}

class _AddPlantButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPlantButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const ShapeDecoration(color: AeroColors.musgo, shape: StadiumBorder()),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Text('Adicionar planta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    ),
  );
}

class _OutlinedChip extends StatelessWidget {
  final String label;
  const _OutlinedChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: AeroColors.mint, borderRadius: BorderRadius.circular(AeroRadius.pilula)),
    child: Text(label, style: const TextStyle(color: AeroColors.musgo, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}
